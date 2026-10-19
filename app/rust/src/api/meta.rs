/// Versão do núcleo Rust; confirma que a ponte está viva.
#[flutter_rust_bridge::frb(sync)]
pub fn core_version() -> String {
    launcher_core::version()
}

/// Primeiro nome do usuário para a saudação; vazio se o sistema não souber.
pub fn user_first_name() -> Option<String> {
    launcher_core::user::current_first_name()
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}
