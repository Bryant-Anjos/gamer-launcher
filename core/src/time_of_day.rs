use serde::{Deserialize, Serialize};
use std::fmt;
use thiserror::Error;

const MINUTES_PER_DAY: u16 = 24 * 60;

/// Horário do dia com precisão de minutos, escrito como "HH:MM".
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(try_from = "String", into = "String")]
pub struct TimeOfDay(u16);

#[derive(Debug, Error, PartialEq, Eq)]
pub enum TimeOfDayError {
    #[error("horário inválido {0:?}: use HH:MM")]
    Format(String),
    #[error("{0} minutos passam da meia-noite")]
    OutOfRange(u16),
}

impl TimeOfDay {
    pub fn from_minutes(minutes: u16) -> Result<Self, TimeOfDayError> {
        if minutes >= MINUTES_PER_DAY {
            return Err(TimeOfDayError::OutOfRange(minutes));
        }
        Ok(Self(minutes))
    }

    pub fn parse(text: &str) -> Result<Self, TimeOfDayError> {
        let invalid = || TimeOfDayError::Format(text.to_string());
        let (hours, minutes) = text.split_once(':').ok_or_else(invalid)?;
        if hours.len() != 2 || minutes.len() != 2 {
            return Err(invalid());
        }
        if !hours
            .bytes()
            .chain(minutes.bytes())
            .all(|b| b.is_ascii_digit())
        {
            return Err(invalid());
        }
        let hours: u16 = hours.parse().map_err(|_| invalid())?;
        let minutes: u16 = minutes.parse().map_err(|_| invalid())?;
        if hours >= 24 || minutes >= 60 {
            return Err(invalid());
        }
        Ok(Self(hours * 60 + minutes))
    }

    pub fn minutes(self) -> u16 {
        self.0
    }
}

impl fmt::Display for TimeOfDay {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{:02}:{:02}", self.0 / 60, self.0 % 60)
    }
}

impl TryFrom<String> for TimeOfDay {
    type Error = TimeOfDayError;

    fn try_from(text: String) -> Result<Self, Self::Error> {
        Self::parse(&text)
    }
}

impl From<TimeOfDay> for String {
    fn from(time: TimeOfDay) -> Self {
        time.to_string()
    }
}
