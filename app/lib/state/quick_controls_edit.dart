import 'package:gamer_launcher/src/rust/api/system.dart';

/// Cópias da leitura com um item trocado (atualização otimista da tela).
extension QuickControlsEdit on QuickControls {
  QuickControls copyWith({
    ToggleReading? wifi,
    ToggleReading? bluetooth,
    ToggleReading? darkMode,
    LevelReading? volume,
    LevelReading? brightness,
  }) => QuickControls(
    wifi: wifi ?? this.wifi,
    wifiName: wifiName,
    bluetooth: bluetooth ?? this.bluetooth,
    darkMode: darkMode ?? this.darkMode,
    volume: volume ?? this.volume,
    brightness: brightness ?? this.brightness,
  );
}

ToggleReading toggleTo(bool enabled) => ToggleReading(enabled: enabled);

LevelReading levelTo(LevelReading current, int percent) =>
    LevelReading(percent: percent, muted: current.muted);
