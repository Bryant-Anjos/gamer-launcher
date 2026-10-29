#![cfg(unix)]
use launcher_core::sound::{SoundPlayer, UiSound, find_program, synth_wav};
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::Path;
use tempfile::tempdir;

fn executable(dir: &Path, name: &str) {
    let path = dir.join(name);
    fs::write(&path, "#!/bin/sh\nexit 0\n").unwrap();
    fs::set_permissions(&path, fs::Permissions::from_mode(0o755)).unwrap();
}

fn le_u32(bytes: &[u8], at: usize) -> u32 {
    u32::from_le_bytes(bytes[at..at + 4].try_into().unwrap())
}

#[test]
fn a_synthesized_sound_is_a_valid_mono_16_bit_wav() {
    let wav = synth_wav(UiSound::Confirm);

    assert_eq!(&wav[0..4], b"RIFF");
    assert_eq!(&wav[8..16], b"WAVEfmt ");
    assert_eq!(le_u32(&wav, 4) as usize, wav.len() - 8);
    assert_eq!(u16::from_le_bytes([wav[22], wav[23]]), 1, "mono");
    assert_eq!(u16::from_le_bytes([wav[34], wav[35]]), 16, "16 bits");
    assert_eq!(&wav[36..40], b"data");
    assert_eq!(le_u32(&wav, 40) as usize, wav.len() - 44);
}

#[test]
fn sounds_are_short_and_distinct() {
    let sounds = [UiSound::Navigate, UiSound::Confirm, UiSound::Back];
    let wavs: Vec<Vec<u8>> = sounds.iter().map(|sound| synth_wav(*sound)).collect();

    for wav in &wavs {
        // 22 050 amostras/s, 2 bytes cada: menos de 0,2 s
        assert!(wav.len() - 44 < 22_050 * 2 / 5, "{}", wav.len());
    }
    assert_ne!(wavs[0], wavs[1]);
    assert_ne!(wavs[1], wavs[2]);
}

#[test]
fn the_sound_starts_and_ends_silent_to_avoid_clicks() {
    let wav = synth_wav(UiSound::Navigate);
    let samples: Vec<i16> = wav[44..]
        .as_chunks::<2>()
        .0
        .iter()
        .map(|pair| i16::from_le_bytes(*pair))
        .collect();

    assert_eq!(samples[0], 0);
    assert!(samples.last().unwrap().abs() < 200);
    assert!(samples.iter().any(|sample| sample.abs() > 1000));
}

#[test]
fn the_first_available_program_in_preference_order_is_chosen() {
    let first = tempdir().unwrap();
    let second = tempdir().unwrap();
    executable(first.path(), "aplay");
    executable(second.path(), "paplay");
    fs::write(second.path().join("pw-play"), "não executável").unwrap();
    let path = std::env::join_paths([first.path(), second.path()]).unwrap();

    let found = find_program(Some(&path), &["pw-play", "paplay", "aplay"]);

    assert_eq!(found, Some(second.path().join("paplay")));
}

#[test]
fn without_any_program_there_is_nothing_to_play_with() {
    let empty = tempdir().unwrap();
    let path = std::env::join_paths([empty.path()]).unwrap();

    assert_eq!(find_program(Some(&path), &["pw-play"]), None);
    assert_eq!(find_program(None, &["pw-play"]), None);
}

#[test]
fn preparing_writes_one_file_per_sound_and_playing_runs_the_program() {
    let bin = tempdir().unwrap();
    let cache = tempdir().unwrap();
    executable(bin.path(), "fake-play");
    let dir = cache.path().join("sounds");

    let player = SoundPlayer::prepare(bin.path().join("fake-play"), &dir).unwrap();

    for sound in [UiSound::Navigate, UiSound::Confirm, UiSound::Back] {
        let file = player.file(sound);
        assert!(file.starts_with(&dir));
        assert_eq!(fs::read(&file).unwrap(), synth_wav(sound));
        player.play(sound).unwrap();
    }
}

#[test]
fn playing_with_a_missing_program_is_an_error() {
    let cache = tempdir().unwrap();
    let player = SoundPlayer::prepare(cache.path().join("nope"), cache.path()).unwrap();

    assert!(player.play(UiSound::Back).is_err());
}
