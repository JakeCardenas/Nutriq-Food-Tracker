import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/domain/day_boundary.dart';
import 'package:nutriq/domain/units.dart';

void main() {
  group('logicalDay', () {
    test('meal after midnight counts toward previous day when day starts at 4 AM', () {
      expect(logicalDay(DateTime(2026, 10, 7, 2, 30), 4), DateTime(2026, 10, 6));
    });

    test('meal exactly at day start belongs to the new day', () {
      expect(logicalDay(DateTime(2026, 10, 7, 4), 4), DateTime(2026, 10, 7));
    });

    test('midnight boundary keeps the calendar date', () {
      expect(logicalDay(DateTime(2026, 10, 7, 0, 5), 0), DateTime(2026, 10, 7));
    });

    test('crosses month boundaries', () {
      expect(logicalDay(DateTime(2026, 11, 1, 1), 3), DateTime(2026, 10, 31));
    });
  });

  group('dayRange', () {
    test('spans from day start to next day start', () {
      final range = dayRange(DateTime(2026, 10, 6), 4);
      expect(range.start, DateTime(2026, 10, 6, 4));
      expect(range.end, DateTime(2026, 10, 7, 4));
    });
  });

  group('units', () {
    test('converts cm to feet and inches', () {
      expect(cmToFeetInches(180), (5, 11));
    });

    test('rolls 12 inches over into the next foot', () {
      expect(cmToFeetInches(182.8), (6, 0));
    });

    test('converts feet and inches to cm', () {
      expect(feetInchesToCm(5, 11), closeTo(180.34, 0.01));
    });

    test('converts kg and lb both ways', () {
      expect(kgToLb(80), closeTo(176.37, 0.01));
      expect(lbToKg(176.37), closeTo(80, 0.01));
    });

    test('formats height and weight per unit system', () {
      expect(formatHeight(180, UnitSystem.metric), '180 cm');
      expect(formatHeight(180, UnitSystem.imperial), '5′ 11″');
      expect(formatWeight(80, UnitSystem.metric), '80 kg');
      expect(formatWeight(80, UnitSystem.imperial), '176 lb');
    });
  });
}
