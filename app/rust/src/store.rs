//! Dados lidos do sistema que as funções da ponte compartilham (apps da
//! última leitura e recentes da pesquisa). Fica fora de `api` para o
//! gerador não expor.

use launcher_core::apps::AppEntry;
use launcher_core::recents::RecentItem;
use std::sync::{Mutex, MutexGuard, PoisonError};

/// Apps da última leitura do catálogo; abrir por id parte daqui.
static APPS: Mutex<Vec<AppEntry>> = Mutex::new(Vec::new());

/// Recentes lidos ao abrir a pesquisa (não a cada tecla).
static SEARCH_RECENTS: Mutex<Vec<RecentItem>> = Mutex::new(Vec::new());

fn unpoisoned<T>(mutex: &'static Mutex<T>) -> MutexGuard<'static, T> {
    // um pânico em outra thread não deve travar a ponte para sempre
    mutex.lock().unwrap_or_else(PoisonError::into_inner)
}

pub fn apps() -> MutexGuard<'static, Vec<AppEntry>> {
    unpoisoned(&APPS)
}

pub fn search_recents() -> MutexGuard<'static, Vec<RecentItem>> {
    unpoisoned(&SEARCH_RECENTS)
}
