//! Sons curtos da interface (navegar, confirmar, voltar), opcionais.
//!
//! Sem biblioteca de áudio: os WAVs são sintetizados aqui, gravados uma vez
//! numa pasta temporária e tocados por um programa que já vem com o sistema
//! (`pw-play` do PipeWire, `paplay` do PulseAudio ou `aplay` do ALSA), sem
//! esperar por ele. Nada é carregado enquanto os sons estão desligados.

use crate::apps::spawn_detached;
use crate::fs_util::write_atomic;
use std::ffi::OsStr;
use std::io;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};

/// Programas que tocam um WAV, na ordem de preferência.
pub const PLAYERS: &[&str] = &["pw-play", "paplay", "aplay"];

const SAMPLE_RATE: u32 = 22_050;
const AMPLITUDE: f32 = 6_000.0;
/// Subida e descida suaves (em ms) para o som não estalar.
const FADE_MS: f32 = 6.0;
const WAV_HEADER_LEN: u32 = 44;
const EXECUTABLE_BITS: u32 = 0o111;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UiSound {
    Navigate,
    Confirm,
    Back,
}

impl UiSound {
    pub const ALL: [UiSound; 3] = [UiSound::Navigate, UiSound::Confirm, UiSound::Back];

    /// (frequência inicial, final em Hz, duração em ms)
    fn tone(self) -> (f32, f32, f32) {
        match self {
            Self::Navigate => (660.0, 660.0, 35.0),
            Self::Confirm => (660.0, 990.0, 90.0),
            Self::Back => (660.0, 440.0, 90.0),
        }
    }

    fn file_name(self) -> &'static str {
        match self {
            Self::Navigate => "navigate.wav",
            Self::Confirm => "confirm.wav",
            Self::Back => "back.wav",
        }
    }
}

fn envelope(index: usize, total: usize) -> f32 {
    let fade = FADE_MS * SAMPLE_RATE as f32 / 1000.0;
    let from_start = index as f32 / fade;
    let to_end = (total - 1 - index) as f32 / fade;
    from_start.min(to_end).min(1.0)
}

fn samples(sound: UiSound) -> Vec<i16> {
    let (from, to, ms) = sound.tone();
    let total = (SAMPLE_RATE as f32 * ms / 1000.0) as usize;
    let mut phase = 0.0_f32;
    (0..total)
        .map(|index| {
            let progress = index as f32 / total as f32;
            let frequency = from + (to - from) * progress;
            let value = phase.sin() * AMPLITUDE * envelope(index, total);
            phase += std::f32::consts::TAU * frequency / SAMPLE_RATE as f32;
            value as i16
        })
        .collect()
}

/// WAV PCM mono de 16 bits com o som pedido.
pub fn synth_wav(sound: UiSound) -> Vec<u8> {
    let data: Vec<u8> = samples(sound)
        .iter()
        .flat_map(|sample| sample.to_le_bytes())
        .collect();
    let data_len = data.len() as u32;
    let mut wav = Vec::with_capacity((WAV_HEADER_LEN + data_len) as usize);
    wav.extend_from_slice(b"RIFF");
    wav.extend_from_slice(&(WAV_HEADER_LEN - 8 + data_len).to_le_bytes());
    wav.extend_from_slice(b"WAVEfmt ");
    wav.extend_from_slice(&16u32.to_le_bytes()); // tamanho do bloco fmt
    wav.extend_from_slice(&1u16.to_le_bytes()); // PCM
    wav.extend_from_slice(&1u16.to_le_bytes()); // mono
    wav.extend_from_slice(&SAMPLE_RATE.to_le_bytes());
    wav.extend_from_slice(&(SAMPLE_RATE * 2).to_le_bytes()); // bytes por segundo
    wav.extend_from_slice(&2u16.to_le_bytes()); // bytes por amostra
    wav.extend_from_slice(&16u16.to_le_bytes()); // bits por amostra
    wav.extend_from_slice(b"data");
    wav.extend_from_slice(&data_len.to_le_bytes());
    wav.extend_from_slice(&data);
    wav
}

fn is_executable(path: &Path) -> bool {
    path.metadata()
        .is_ok_and(|meta| meta.is_file() && meta.permissions().mode() & EXECUTABLE_BITS != 0)
}

/// Primeiro programa de `candidates` (na ordem dada) que existe no `PATH`.
pub fn find_program(path_var: Option<&OsStr>, candidates: &[&str]) -> Option<PathBuf> {
    let dirs: Vec<PathBuf> = std::env::split_paths(path_var?).collect();
    candidates.iter().find_map(|name| {
        dirs.iter()
            .map(|dir| dir.join(name))
            .find(|path| is_executable(path))
    })
}

/// Toca os sons com um programa externo. Criado só quando o usuário liga os sons.
#[derive(Debug, Clone)]
pub struct SoundPlayer {
    program: PathBuf,
    dir: PathBuf,
}

impl SoundPlayer {
    /// Grava os WAVs em `dir` (substituindo o que houver) e guarda o programa.
    pub fn prepare(program: PathBuf, dir: &Path) -> io::Result<Self> {
        for sound in UiSound::ALL {
            write_atomic(&dir.join(sound.file_name()), &synth_wav(sound))?;
        }
        Ok(Self {
            program,
            dir: dir.to_path_buf(),
        })
    }

    pub fn file(&self, sound: UiSound) -> PathBuf {
        self.dir.join(sound.file_name())
    }

    /// Começa a tocar e volta na hora (o processo é recolhido em segundo plano).
    pub fn play(&self, sound: UiSound) -> io::Result<()> {
        let file = self.file(sound).to_string_lossy().into_owned();
        spawn_detached(&self.program.to_string_lossy(), &[file], None)
    }
}
