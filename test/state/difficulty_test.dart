import 'package:flutter_test/flutter_test.dart';
import 'package:numberama/state/difficulty.dart';

void main() {
  group('Difficulty.forDate', () {
    test('rotates through every tier across consecutive days', () {
      // 3 consecutive days must cover all 3 tiers exactly once, whichever
      // tier the sequence happens to start on - this is the actual product
      // requirement ("every difficulty level should be different").
      final start = DateTime.utc(2026, 3, 5);
      final tiers = [
        for (var i = 0; i < 3; i++)
          Difficulty.forDate(start.add(Duration(days: i))),
      ];
      expect(tiers.toSet(), Difficulty.values.toSet());
    });

    test('is deterministic - the same date always yields the same tier', () {
      final date = DateTime.utc(2026, 7, 14);
      expect(Difficulty.forDate(date), Difficulty.forDate(date));
    });

    test('only depends on the calendar day, not the time of day', () {
      final morning = DateTime.utc(2026, 7, 14, 1);
      final night = DateTime.utc(2026, 7, 14, 23, 59);
      expect(Difficulty.forDate(morning), Difficulty.forDate(night));
    });
  });

  group('Difficulty tiers actually differ mechanically', () {
    test('auto-row interval gets faster from easy to hard', () {
      expect(Difficulty.easy.autoRowIntervalSeconds,
          greaterThan(Difficulty.medium.autoRowIntervalSeconds));
      expect(Difficulty.medium.autoRowIntervalSeconds,
          greaterThan(Difficulty.hard.autoRowIntervalSeconds));
    });

    test('starting rows increase from easy to hard', () {
      expect(Difficulty.easy.initialRows, lessThan(Difficulty.medium.initialRows));
      expect(Difficulty.medium.initialRows, lessThan(Difficulty.hard.initialRows));
    });

    test('only hard removes power-ups entirely', () {
      expect(Difficulty.easy.powerUpsEnabled, isTrue);
      expect(Difficulty.medium.powerUpsEnabled, isTrue);
      expect(Difficulty.hard.powerUpsEnabled, isFalse);
    });

    test('only easy narrows the tile value range', () {
      expect(Difficulty.easy.maxTileValue, lessThan(Difficulty.medium.maxTileValue));
      expect(Difficulty.medium.maxTileValue, Difficulty.hard.maxTileValue);
    });
  });
}
