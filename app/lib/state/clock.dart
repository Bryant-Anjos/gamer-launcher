import 'dart:async';

import 'package:flutter/foundation.dart';

const _minute = Duration(minutes: 1);

/// Hora atual com precisão de minuto: um timer por minuto, alinhado à
/// virada, para o relógio, a saudação e o tema automático.
class Clock extends ValueNotifier<DateTime> {
  Clock({DateTime Function() now = DateTime.now}) : _now = now, super(now()) {
    _scheduleNext();
  }

  final DateTime Function() _now;
  Timer? _timer;

  void _scheduleNext() {
    final current = _now();
    final next = DateTime(
      current.year,
      current.month,
      current.day,
      current.hour,
      current.minute,
    ).add(_minute);
    _timer = Timer(next.difference(current), () {
      value = _now();
      _scheduleNext();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
