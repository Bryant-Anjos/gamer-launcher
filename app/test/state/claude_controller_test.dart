import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/state/claude_controller.dart';

import '../support/fake_backend.dart';
import '../support/samples.dart';

void main() {
  final now = DateTime(2026, 10, 19, 9);

  test('reads the sessions and the stats only while someone watches', () {
    fakeAsync((async) {
      final backend = FakeBackend(
        isClaudeInstalled: true,
        claudeNow: sampleClaudeNow,
        claudeStats: sampleClaudeStats,
      );
      final claude = ClaudeController(backend, now: () => now);
      async.elapse(const Duration(minutes: 2));
      expect(backend.calls.where((c) => c.startsWith('readClaude')), isEmpty);

      claude.attach();
      async.flushMicrotasks();

      expect(claude.value.now, sampleClaudeNow);
      expect(claude.value.stats, sampleClaudeStats);
      claude.detach();
      claude.dispose();
    });
  });

  test('sessions are read often and stats rarely', () {
    fakeAsync((async) {
      final backend = FakeBackend(isClaudeInstalled: true);
      final claude = ClaudeController(backend, now: () => now)..attach();

      async.elapse(const Duration(seconds: 61));
      final reads = backend.calls.where((c) => c == 'readClaudeNow').length;
      final stats = backend.calls.where((c) => c == 'readClaudeStats').length;

      expect(reads, greaterThanOrEqualTo(10));
      expect(stats, 2);
      claude.dispose();
    });
  });

  test('a failed read keeps the last values and shows no error', () {
    fakeAsync((async) {
      final backend = FakeBackend(
        isClaudeInstalled: true,
        claudeNow: sampleClaudeNow,
      );
      final claude = ClaudeController(backend, now: () => now)..attach();
      async.flushMicrotasks();

      backend.failures['readClaudeNow'] = 'formato novo';
      async.elapse(claudeNowInterval);

      expect(claude.value.now, sampleClaudeNow);
      claude.dispose();
    });
  });

  test('working counts sessions and agents that are busy', () {
    final state = ClaudeState(now: sampleClaudeNow);

    expect(state.busySessions, 1);
    expect(state.runningAgents, 1);
  });
}
