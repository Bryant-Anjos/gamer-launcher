//! Arquivos recentes a partir do `recently-used.xbel` (padrão GTK/freedesktop).

use quick_xml::events::Event;
use quick_xml::{Reader, XmlVersion};
use std::path::{Path, PathBuf};
use std::{fs, io};
use thiserror::Error;

const FILE_SCHEME: &str = "file://";

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RecentItem {
    pub path: PathBuf,
    /// Data ISO 8601 em UTC, como veio no arquivo.
    pub modified: String,
}

#[derive(Debug, Error)]
pub enum RecentsError {
    #[error("falha ao ler os arquivos recentes: {0}")]
    Io(#[from] io::Error),
    #[error("arquivo de recentes inválido: {0}")]
    Parse(String),
}

fn hex_value(byte: u8) -> Option<u8> {
    (byte as char).to_digit(16).map(|digit| digit as u8)
}

/// Decodifica `%XX`; sequências inválidas ficam como estão.
fn percent_decode(text: &str) -> Vec<u8> {
    let bytes = text.as_bytes();
    let mut decoded = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        let escaped = match (bytes[i], bytes.get(i + 1), bytes.get(i + 2)) {
            (b'%', Some(&high), Some(&low)) => hex_value(high)
                .zip(hex_value(low))
                .map(|(high, low)| high * 16 + low),
            _ => None,
        };
        match escaped {
            Some(byte) => {
                decoded.push(byte);
                i += 3;
            }
            None => {
                decoded.push(bytes[i]);
                i += 1;
            }
        }
    }
    decoded
}

#[cfg(unix)]
fn path_from_bytes(bytes: Vec<u8>) -> PathBuf {
    use std::os::unix::ffi::OsStringExt;
    PathBuf::from(std::ffi::OsString::from_vec(bytes))
}

#[cfg(not(unix))]
fn path_from_bytes(bytes: Vec<u8>) -> PathBuf {
    PathBuf::from(String::from_utf8_lossy(&bytes).into_owned())
}

/// Só caminhos locais absolutos: `file:///x` e `file://localhost/x`.
fn local_path(href: &str) -> Option<PathBuf> {
    let rest = href.strip_prefix(FILE_SCHEME)?;
    let rest = rest.strip_prefix("localhost").unwrap_or(rest);
    rest.starts_with('/')
        .then(|| path_from_bytes(percent_decode(rest)))
}

/// Chave de ordenação: segundos e fração (alinhada à direita em zeros),
/// pois "…:00Z" e "…:00.5Z" não comparam bem como texto.
fn time_key(modified: &str) -> (String, String) {
    let seconds = modified
        .split(['.', 'Z', '+'])
        .next()
        .unwrap_or_default()
        .to_string();
    let fraction: String = modified
        .split_once('.')
        .map(|(_, rest)| rest.chars().take_while(char::is_ascii_digit).collect())
        .unwrap_or_default();
    (seconds, format!("{fraction:0<9}"))
}

fn bookmark_item(
    element: &quick_xml::events::BytesStart,
) -> Result<Option<RecentItem>, RecentsError> {
    let mut href = None;
    let mut modified = None;
    let mut added = None;
    for attribute in element.attributes() {
        let attribute = attribute.map_err(|error| RecentsError::Parse(error.to_string()))?;
        let value = attribute
            .normalized_value(XmlVersion::default())
            .map_err(|error| RecentsError::Parse(error.to_string()))?
            .into_owned();
        match attribute.key.as_ref() {
            "href" => href = Some(value),
            "modified" => modified = Some(value),
            "added" => added = Some(value),
            _ => {}
        }
    }
    let Some(path) = href.as_deref().and_then(local_path) else {
        return Ok(None);
    };
    Ok(Some(RecentItem {
        path,
        modified: modified.or(added).unwrap_or_default(),
    }))
}

/// Arquivos locais do documento, do mais recente para o mais antigo.
pub fn parse_recents(xml: &str, limit: usize) -> Result<Vec<RecentItem>, RecentsError> {
    let mut reader = Reader::from_str(xml);
    let mut items = Vec::new();
    loop {
        match reader.read_event() {
            Ok(Event::Start(element)) | Ok(Event::Empty(element))
                if element.name().as_ref() == "bookmark" =>
            {
                items.extend(bookmark_item(&element)?);
            }
            Ok(Event::Eof) => break,
            Ok(_) => {}
            Err(error) => return Err(RecentsError::Parse(error.to_string())),
        }
    }
    items.sort_by_key(|item| std::cmp::Reverse(time_key(&item.modified)));
    items.truncate(limit);
    Ok(items)
}

/// Lê o arquivo de recentes e descarta o que não existe mais no disco.
/// Arquivo ausente significa lista vazia.
pub fn load_recents(path: &Path, limit: usize) -> Result<Vec<RecentItem>, RecentsError> {
    let xml = match fs::read_to_string(path) {
        Ok(xml) => xml,
        Err(error) if error.kind() == io::ErrorKind::NotFound => return Ok(Vec::new()),
        Err(error) => return Err(error.into()),
    };
    let mut items = parse_recents(&xml, usize::MAX)?;
    items.retain(|item| item.path.exists());
    items.truncate(limit);
    Ok(items)
}
