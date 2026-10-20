import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/ui/settings/input_settings.dart';
import 'package:gamer_launcher/ui/widgets/svg_icon.dart';

import '../support/font_cmap.dart';
import '../support/harness.dart';

final _iconUse = RegExp(r'Icons\.([a-z0-9_]+)');
final _iconDeclaration = RegExp(
  r'static const IconData ([a-z0-9_]+) =\s*IconData\(\s*(0x[0-9a-f]+)',
);

/// Ícone sem glifo na fonte aparece como outro caractere (um ideograma, por
/// exemplo, quando outra fonte do sistema tem algo naquele código).
void main() {
  final root = Platform.environment['FLUTTER_ROOT'];

  test('every Material icon used by the app has a glyph in the font', () {
    final sdk = '$root/packages/flutter/lib/src/material/icons.dart';
    final codepoints = {
      for (final m in _iconDeclaration.allMatches(File(sdk).readAsStringSync()))
        m.group(1)!: int.parse(m.group(2)!),
    };
    final font = File(
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytesSync();
    final glyphs = fontCodepoints(font);
    final used = {
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          for (final m in _iconUse.allMatches(file.readAsStringSync()))
            m.group(1)!,
    };

    expect(used, isNotEmpty);
    for (final name in used) {
      final codepoint = codepoints[name];
      expect(codepoint, isNotNull, reason: 'Icons.$name não existe no SDK');
      expect(glyphs, contains(codepoint), reason: 'Icons.$name sem glifo');
    }
  }, skip: root == null ? 'sem FLUTTER_ROOT' : false);

  testWidgets('the button layout choices show real icons', (tester) async {
    await pumpLauncher(tester);
    await tester.tap(find.text('Configurações'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Nintendo'), 200);

    final choices = find.byType(ButtonLayoutChoices);
    expect(
      find.descendant(
        of: choices,
        matching: find.byIcon(Icons.autorenew_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: choices, matching: find.byType(PadIcon)),
      findsOneWidget,
    );
  });
}
