use launcher_core::system::{CommandRunner, ProcessRunner, SystemError};
use std::time::Duration;

#[test]
fn returns_standard_output() {
    let output = ProcessRunner::default().run("echo", &["oi"]).unwrap();

    assert_eq!(output, "oi\n");
}

#[test]
fn a_failing_command_reports_its_error_text() {
    let error = ProcessRunner::default()
        .run("sh", &["-c", "echo deu-ruim >&2; exit 3"])
        .unwrap_err();

    match error {
        SystemError::CommandFailed { program, message } => {
            assert_eq!(program, "sh");
            assert!(message.contains("deu-ruim"), "{message}");
        }
        other => panic!("erro inesperado: {other:?}"),
    }
}

#[test]
fn a_missing_program_is_a_command_failure() {
    let error = ProcessRunner::default()
        .run("programa-que-nao-existe-xyz", &[])
        .unwrap_err();

    assert!(matches!(error, SystemError::CommandFailed { .. }));
}

#[test]
fn slow_commands_are_killed_after_the_timeout() {
    let runner = ProcessRunner::with_timeout(Duration::from_millis(200));

    let started = std::time::Instant::now();
    let error = runner.run("sleep", &["5"]).unwrap_err();

    assert!(matches!(error, SystemError::Timeout { .. }));
    assert!(started.elapsed() < Duration::from_secs(3));
}

#[test]
fn commands_run_with_the_c_locale() {
    let output = ProcessRunner::default()
        .run("sh", &["-c", "echo $LC_ALL"])
        .unwrap();

    assert_eq!(output.trim(), "C");
}

#[test]
fn shared_runners_work_through_arc() {
    let runner = std::sync::Arc::new(ProcessRunner::default());

    assert_eq!(runner.run("echo", &["x"]).unwrap(), "x\n");
}
