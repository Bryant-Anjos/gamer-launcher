/// Formatação de textos da tela em português, sem depender de pacote de
/// internacionalização (só precisamos de poucos formatos fixos).
library;

const _weekdays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
const _months = [
  'Jan',
  'Fev',
  'Mar',
  'Abr',
  'Mai',
  'Jun',
  'Jul',
  'Ago',
  'Set',
  'Out',
  'Nov',
  'Dez',
];

const _morningStartsAt = 5;
const _afternoonStartsAt = 12;
const _eveningStartsAt = 18;
const _minutesPerHour = 60;
const _hoursPerDay = 24;
const _bytesPerGigabyte = 1e9;
const _decimalsBelow = 10;

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String formatClock(DateTime time) =>
    '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}';

/// Ex.: "Sex, 16 de Out".
String formatShortDate(DateTime date) =>
    '${_weekdays[date.weekday - 1]}, ${date.day} de ${_months[date.month - 1]}';

String formatMinuteOfDay(int minutes) =>
    '${_twoDigits(minutes ~/ _minutesPerHour)}:'
    '${_twoDigits(minutes % _minutesPerHour)}';

String greetingFor(DateTime time) {
  final hour = time.hour;
  if (hour >= _morningStartsAt && hour < _afternoonStartsAt) return 'Bom dia';
  if (hour >= _afternoonStartsAt && hour < _eveningStartsAt) {
    return 'Boa tarde';
  }
  return 'Boa noite';
}

/// Saudação com o nome, quando o sistema souber qual é.
String greetingLine(DateTime time, String? name) {
  final greeting = greetingFor(time);
  final trimmed = name?.trim() ?? '';
  return trimmed.isEmpty ? greeting : '$greeting, $trimmed';
}

/// "há 2h", "há 1 dia"... a partir de uma data ISO 8601. Texto vazio
/// quando a data não pode ser lida.
String formatRelative(String isoDate, DateTime now) {
  final date = DateTime.tryParse(isoDate);
  if (date == null) return '';
  final elapsed = now.difference(date);
  if (elapsed.inMinutes < 1) return 'agora';
  if (elapsed.inHours < 1) return 'há ${elapsed.inMinutes} min';
  if (elapsed.inHours < _hoursPerDay) return 'há ${elapsed.inHours}h';
  final days = elapsed.inDays;
  return days == 1 ? 'há 1 dia' : 'há $days dias';
}

String formatGigabytes(double bytes) {
  final gigabytes = bytes / _bytesPerGigabyte;
  if (gigabytes == 0) return '0';
  return gigabytes < _decimalsBelow
      ? gigabytes.toStringAsFixed(1)
      : gigabytes.round().toString();
}

/// Ex.: "4.2 / 16 GB".
String formatUsage(double usedBytes, double totalBytes) =>
    '${formatGigabytes(usedBytes)} / ${formatGigabytes(totalBytes)} GB';
