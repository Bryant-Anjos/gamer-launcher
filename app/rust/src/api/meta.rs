/// Versão do núcleo Rust; confirma que a ponte está viva.
#[flutter_rust_bridge::frb(sync)]
pub fn core_version() -> String {
    launcher_core::version()
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}
