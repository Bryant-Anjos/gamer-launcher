import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/src/rust/api/input.dart';
import 'package:gamer_launcher/ui/claude/claude_page.dart';
import 'package:gamer_launcher/ui/claude/claude_panel.dart';
import 'package:gamer_launcher/ui/claude/claude_widgets.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';
import '../support/samples.dart';

FakeBackend _installed() => FakeBackend(
  isClaudeInstalled: true,
  claudeNow: sampleClaudeNow,
  claudeStats: sampleClaudeStats,
);

Future<LauncherHarness> _openPage(WidgetTester tester) async {
  final h = await pumpLauncher(tester, backend: _installed());
  await tester.tap(find.text('Claude'));
  await tester.pumpAndSettle();
  return h;
}

void main() {
  group('without Claude Code', () {
    testWidgets('nothing shows and nothing is read', (tester) async {
      final h = await pumpLauncher(tester);
      await tester.pump(const Duration(minutes: 2));

      expect(find.byType(ClaudePanel), findsNothing);
      expect(find.text('Claude'), findsNothing);
      expect(h.backend.calls.where((c) => c.startsWith('readClaude')), isEmpty);
    });

    testWidgets('the settings do not offer its panel', (tester) async {
      final h = await pumpLauncher(tester);
      for (var i = 0; i < 4; i++) {
        await h.pressAndSettle(tester, GamepadAction.tabNext);
      }

      expect(find.text('Configurações'), findsWidgets);
      expect(find.text('Claude Code'), findsNothing);
    });
  });

  group('with Claude Code', () {
    testWidgets('the home panel sums up sessions, agents and today', (
      tester,
    ) async {
      await pumpLauncher(tester, backend: _installed());

      final panel = find.byType(ClaudePanel);
      expect(panel, findsOneWidget);
      Finder inPanel(String text) =>
          find.descendant(of: panel, matching: find.textContaining(text));
      expect(inPanel('2 sessões abertas'), findsOneWidget);
      expect(inPanel('1 trabalhando'), findsOneWidget);
      expect(inPanel('1 agente'), findsOneWidget);
      expect(inPanel('298 respostas'), findsOneWidget);
    });

    testWidgets('the panel opens the Claude section', (tester) async {
      await pumpLauncher(tester, backend: _installed());

      await tester.ensureVisible(find.text('Ver detalhes'));
      await tester.tap(find.text('Ver detalhes'));
      await tester.pumpAndSettle();

      expect(find.byType(ClaudePage), findsOneWidget);
    });

    testWidgets('the section lists sessions with model, branch and agents', (
      tester,
    ) async {
      await _openPage(tester);

      expect(find.text('gamer-launcher'), findsOneWidget);
      expect(find.text('Painel do Claude'), findsOneWidget);
      expect(find.textContaining('claude-opus-5'), findsWidgets);
      expect(find.textContaining('main'), findsWidgets);
      expect(find.textContaining('Achar o leitor de sessões'), findsOneWidget);
      expect(find.text('homeflix'), findsOneWidget);
    });

    testWidgets('the section shows today, the week chart and the history', (
      tester,
    ) async {
      await _openPage(tester);
      await tester.scrollUntilVisible(find.byType(DayBars), 300);

      expect(find.text('298'), findsWidgets);
      expect(find.text('1,2 mi'), findsWidgets);
      expect(find.byType(DayBars), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('40 sessões'), 300);
      expect(find.textContaining('13/10'), findsWidgets);
    });

    testWidgets('LB and RB go through the Claude section too', (tester) async {
      final h = await pumpLauncher(tester, backend: _installed());

      for (var i = 0; i < 4; i++) {
        await h.pressAndSettle(tester, GamepadAction.tabNext);
      }

      expect(find.byType(ClaudePage), findsOneWidget);
    });

    testWidgets('hiding the panel in the settings removes it', (tester) async {
      final backend = _installed();
      await pumpLauncher(tester, backend: backend);
      await tester.tap(find.text('Configurações'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Claude Code'), 200);
      await tester.tap(find.text('Claude Code'));
      await tester.pumpAndSettle();

      expect(backend.saved.last.panels.claude, isFalse);
    });

    testWidgets('no session open says so', (tester) async {
      final backend = FakeBackend(isClaudeInstalled: true);
      await pumpLauncher(tester, backend: backend);
      await tester.tap(find.text('Claude'));
      await tester.pumpAndSettle();

      expect(find.text(noClaudeSessionsText), findsOneWidget);
    });
  });
}
