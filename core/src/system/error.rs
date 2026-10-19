use thiserror::Error;

/// Erros ao falar com o sistema. Só texto, para poder copiar e enviar à UI.
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum SystemError {
    #[error("{program} falhou: {message}")]
    CommandFailed { program: String, message: String },
    #[error("{program} demorou mais de {seconds}s")]
    Timeout { program: String, seconds: u64 },
    #[error("resposta inesperada: {0}")]
    Parse(String),
    #[error("indisponível: {0}")]
    Unavailable(String),
    #[error("falha de arquivo: {0}")]
    Io(String),
}
