//! Datas sem dependências: o Claude grava horários ISO 8601 em UTC e a tela
//! agrupa por dia local (o deslocamento vem de fora, testável).

const DAY_MS: i64 = 86_400_000;
const MINUTE_MS: i64 = 60_000;

/// Dias desde 1970-01-01 para uma data civil (algoritmo de Howard Hinnant).
fn days_from_civil(year: i64, month: i64, day: i64) -> i64 {
    let y = if month <= 2 { year - 1 } else { year };
    let era = y.div_euclid(400);
    let yoe = y - era * 400;
    let mp = (month + 9) % 12;
    let doy = (153 * mp + 2) / 5 + day - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146_097 + doe - 719_468
}

fn civil_from_days(days: i64) -> (i64, i64, i64) {
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let day = doy - (153 * mp + 2) / 5 + 1;
    let month = if mp < 10 { mp + 3 } else { mp - 9 };
    let year = yoe + era * 400 + i64::from(month <= 2);
    (year, month, day)
}

fn number(text: &str, range: std::ops::Range<usize>) -> Option<i64> {
    text.get(range)?.parse().ok()
}

/// `AAAA-MM-DDTHH:MM:SS[.fff]Z` em milissegundos desde 1970 (UTC).
pub fn parse_iso_ms(text: &str) -> Option<i64> {
    let bytes = text.as_bytes();
    if bytes.len() < 20 || bytes[4] != b'-' || bytes[10] != b'T' || !text.ends_with('Z') {
        return None;
    }
    let (year, month, day) = (
        number(text, 0..4)?,
        number(text, 5..7)?,
        number(text, 8..10)?,
    );
    let (hour, minute, second) = (
        number(text, 11..13)?,
        number(text, 14..16)?,
        number(text, 17..19)?,
    );
    let valid = (1..=12).contains(&month)
        && (1..=31).contains(&day)
        && hour < 24
        && minute < 60
        && second < 61;
    if !valid {
        return None;
    }
    let millis = match text.get(19..text.len() - 1) {
        Some(fraction) if fraction.starts_with('.') => {
            let digits: String = fraction[1..].chars().chain("000".chars()).take(3).collect();
            digits.parse().ok()?
        }
        Some("") => 0,
        _ => return None,
    };
    let seconds = days_from_civil(year, month, day) * 86_400 + hour * 3600 + minute * 60 + second;
    Some(seconds * 1000 + millis)
}

/// Dia local (dias desde 1970) de um instante, com o deslocamento em minutos.
pub fn day_of(epoch_ms: i64, offset_minutes: i32) -> i64 {
    (epoch_ms + i64::from(offset_minutes) * MINUTE_MS).div_euclid(DAY_MS)
}

/// `AAAA-MM-DD` de um dia local.
pub fn day_to_date(day: i64) -> String {
    let (year, month, date) = civil_from_days(day);
    format!("{year:04}-{month:02}-{date:02}")
}

/// Dia local de uma data `AAAA-MM-DD` (as do cache de estatísticas).
pub fn date_to_day(date: &str) -> Option<i64> {
    if date.len() != 10 {
        return None;
    }
    Some(days_from_civil(
        number(date, 0..4)?,
        number(date, 5..7)?,
        number(date, 8..10)?,
    ))
}
