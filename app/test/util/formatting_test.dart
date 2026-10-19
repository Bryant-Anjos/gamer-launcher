import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/util/formatting.dart';

void main() {
  group('formatClock', () {
    test('pads hours and minutes', () {
      expect(formatClock(DateTime(2026, 10, 16, 9, 5)), '09:05');
      expect(formatClock(DateTime(2026, 10, 16, 19, 42)), '19:42');
    });
  });

  group('formatShortDate', () {
    test('writes the weekday and month in Portuguese', () {
      expect(formatShortDate(DateTime(2026, 10, 16)), 'Sex, 16 de Out');
      expect(formatShortDate(DateTime(2026, 10, 19)), 'Seg, 19 de Out');
      expect(formatShortDate(DateTime(2026, 3, 1)), 'Dom, 1 de Mar');
    });
  });

  group('greetingFor', () {
    test('changes with the time of day', () {
      expect(greetingFor(DateTime(2026, 1, 1, 5)), 'Bom dia');
      expect(greetingFor(DateTime(2026, 1, 1, 11, 59)), 'Bom dia');
      expect(greetingFor(DateTime(2026, 1, 1, 12)), 'Boa tarde');
      expect(greetingFor(DateTime(2026, 1, 1, 17, 59)), 'Boa tarde');
      expect(greetingFor(DateTime(2026, 1, 1, 18)), 'Boa noite');
      expect(greetingFor(DateTime(2026, 1, 1, 4, 59)), 'Boa noite');
    });

    test('adds the name when known', () {
      final evening = DateTime(2026, 1, 1, 20);

      expect(greetingLine(evening, 'Bryant'), 'Boa noite, Bryant');
      expect(greetingLine(evening, null), 'Boa noite');
      expect(greetingLine(evening, '  '), 'Boa noite');
    });
  });

  group('formatRelative', () {
    final now = DateTime.utc(2026, 10, 19, 12);

    test('uses the largest unit that fits', () {
      expect(formatRelative('2026-10-19T11:59:40Z', now), 'agora');
      expect(formatRelative('2026-10-19T11:45:00Z', now), 'há 15 min');
      expect(formatRelative('2026-10-19T09:30:00.123Z', now), 'há 2h');
      expect(formatRelative('2026-10-18T11:00:00Z', now), 'há 1 dia');
      expect(formatRelative('2026-10-10T12:00:00Z', now), 'há 9 dias');
    });

    test('future and unreadable dates do not break', () {
      expect(formatRelative('2026-10-19T13:00:00Z', now), 'agora');
      expect(formatRelative('', now), '');
      expect(formatRelative('ontem', now), '');
    });
  });

  group('formatGigabytes', () {
    test('shows one decimal below ten and none above', () {
      expect(formatGigabytes(4.2e9), '4.2');
      expect(formatGigabytes(120e9), '120');
      expect(formatGigabytes(0), '0');
    });

    test('formats a used over total pair', () {
      expect(formatUsage(4.2e9, 16e9), '4.2 / 16 GB');
    });
  });

  group('formatMinuteOfDay', () {
    test('writes HH:MM', () {
      expect(formatMinuteOfDay(0), '00:00');
      expect(formatMinuteOfDay(19 * 60 + 30), '19:30');
    });
  });
}
