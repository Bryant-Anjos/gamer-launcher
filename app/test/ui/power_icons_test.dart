import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/ui/power/power_icons.dart';

import '../support/harness.dart';

void main() {
  test('every power glyph has its SVG in the assets', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final glyph in PowerGlyph.values) {
      final svg = await rootBundle.loadString(glyph.asset);
      expect(svg, contains('<svg'), reason: glyph.name);
      expect(svg, contains('stroke-width="2"'), reason: glyph.name);
    }
  });

  testWidgets('the power menu uses the system-like glyphs, one per option', (
    tester,
  ) async {
    await pumpLauncher(tester);
    await tester.tap(find.text('Energia'));
    await tester.pumpAndSettle();

    final shown = tester
        .widgetList<PowerIcon>(find.byType(PowerIcon))
        .map((icon) => icon.glyph)
        .toList();
    // o primeiro é o do botão Energia na navegação
    expect(shown, [
      PowerGlyph.shutdown,
      PowerGlyph.suspend,
      PowerGlyph.restart,
      PowerGlyph.shutdown,
      PowerGlyph.logOut,
      PowerGlyph.closeLauncher,
    ]);
  });
}
