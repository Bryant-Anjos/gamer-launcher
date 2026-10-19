import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/input/gamepad_stream.dart';
import 'package:gamer_launcher/src/rust/api/input.dart';

void main() {
  test('does not start reading until someone listens', () {
    var starts = 0;

    gamepadStream(
      start: () {
        starts++;
        return const Stream.empty();
      },
      stop: () {},
    );

    expect(starts, 0);
  });

  test('forwards actions from the source', () async {
    final source = StreamController<GamepadAction>();
    final received = <GamepadAction>[];
    final stream = gamepadStream(start: () => source.stream, stop: () {});

    final subscription = stream.listen(received.add);
    source
      ..add(GamepadAction.up)
      ..add(GamepadAction.confirm);
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(received, [GamepadAction.up, GamepadAction.confirm]);
  });

  test('stops reading when the listener cancels', () async {
    final source = StreamController<GamepadAction>();
    var stops = 0;
    final stream = gamepadStream(
      start: () => source.stream,
      stop: () => stops++,
    );

    await stream.listen((_) {}).cancel();

    expect(stops, 1);
    expect(source.hasListener, isFalse);
  });

  test('a source that fails does not break the stream', () async {
    final stream = gamepadStream(
      start: () => Stream<GamepadAction>.error(StateError('sem udev')),
      stop: () {},
    );
    final received = <GamepadAction>[];
    var errors = 0;

    final subscription = stream.listen(received.add, onError: (_) => errors++);
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(received, isEmpty);
    expect(errors, 0, reason: 'o erro é registrado, não repassado à UI');
  });
}
