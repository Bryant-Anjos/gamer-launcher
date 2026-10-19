use super::SystemError;
use std::io::Read;
use std::process::{Command, Stdio};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};

const DEFAULT_TIMEOUT: Duration = Duration::from_secs(5);
const POLL_INTERVAL: Duration = Duration::from_millis(10);

/// Executa um programa e devolve o que ele escreveu na saída padrão.
/// Existe como trait para os testes trocarem o sistema real por um falso.
pub trait CommandRunner: Send + Sync {
    fn run(&self, program: &str, args: &[&str]) -> Result<String, SystemError>;
}

impl<T: CommandRunner + ?Sized> CommandRunner for Arc<T> {
    fn run(&self, program: &str, args: &[&str]) -> Result<String, SystemError> {
        (**self).run(program, args)
    }
}

/// Roda processos de verdade, sem shell, com o locale `C` (saídas estáveis,
/// sem tradução) e um limite de tempo.
#[derive(Debug, Clone)]
pub struct ProcessRunner {
    timeout: Duration,
}

impl ProcessRunner {
    pub fn with_timeout(timeout: Duration) -> Self {
        Self { timeout }
    }
}

impl Default for ProcessRunner {
    fn default() -> Self {
        Self::with_timeout(DEFAULT_TIMEOUT)
    }
}

fn read_in_background<R: Read + Send + 'static>(mut source: R) -> thread::JoinHandle<Vec<u8>> {
    thread::spawn(move || {
        let mut bytes = Vec::new();
        let _ = source.read_to_end(&mut bytes);
        bytes
    })
}

impl CommandRunner for ProcessRunner {
    fn run(&self, program: &str, args: &[&str]) -> Result<String, SystemError> {
        let failed = |message: String| SystemError::CommandFailed {
            program: program.to_string(),
            message,
        };
        let mut child = Command::new(program)
            .args(args)
            .env("LC_ALL", "C")
            .env("LANG", "C")
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .map_err(|error| failed(error.to_string()))?;
        let stdout = child.stdout.take().map(read_in_background);
        let stderr = child.stderr.take().map(read_in_background);

        let deadline = Instant::now() + self.timeout;
        let status = loop {
            match child
                .try_wait()
                .map_err(|error| failed(error.to_string()))?
            {
                Some(status) => break status,
                None if Instant::now() >= deadline => {
                    let _ = child.kill();
                    let _ = child.wait();
                    return Err(SystemError::Timeout {
                        program: program.to_string(),
                        seconds: self.timeout.as_secs().max(1),
                    });
                }
                None => thread::sleep(POLL_INTERVAL),
            }
        };

        let collect = |handle: Option<thread::JoinHandle<Vec<u8>>>| {
            handle
                .and_then(|handle| handle.join().ok())
                .map(|bytes| String::from_utf8_lossy(&bytes).into_owned())
                .unwrap_or_default()
        };
        let (output, errors) = (collect(stdout), collect(stderr));
        if status.success() {
            return Ok(output);
        }
        let errors = errors.trim();
        Err(failed(if errors.is_empty() {
            format!("saiu com {status}")
        } else {
            errors.to_string()
        }))
    }
}
