use launcher_core::system::{CommandRunner, SystemError};
use std::collections::HashMap;
use std::sync::Mutex;

/// Executor falso: responde só ao que foi combinado e registra as chamadas.
#[derive(Default)]
pub struct FakeRunner {
    replies: Mutex<HashMap<String, Result<String, SystemError>>>,
    calls: Mutex<Vec<String>>,
}

impl FakeRunner {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn reply(self, command: &str, output: &str) -> Self {
        self.replies
            .lock()
            .unwrap()
            .insert(command.into(), Ok(output.into()));
        self
    }

    pub fn fail(self, command: &str, error: SystemError) -> Self {
        self.replies
            .lock()
            .unwrap()
            .insert(command.into(), Err(error));
        self
    }

    pub fn calls(&self) -> Vec<String> {
        self.calls.lock().unwrap().clone()
    }
}

impl CommandRunner for FakeRunner {
    fn run(&self, program: &str, args: &[&str]) -> Result<String, SystemError> {
        let command = std::iter::once(program)
            .chain(args.iter().copied())
            .collect::<Vec<_>>()
            .join(" ");
        self.calls.lock().unwrap().push(command.clone());
        self.replies
            .lock()
            .unwrap()
            .get(&command)
            .cloned()
            .unwrap_or_else(|| {
                Err(SystemError::CommandFailed {
                    program: program.into(),
                    message: format!("comando não combinado no teste: {command}"),
                })
            })
    }
}
