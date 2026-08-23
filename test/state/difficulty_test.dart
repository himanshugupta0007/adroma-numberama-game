import 'package:flutter_test/flutter_test.dart';
import 'package:numberama/state/difficulty.dart';

void main() {
  group('Difficulty.forDate', () {
    test('is deterministic - the same date always yields the same tier', () {
      final date = DateTime.utc(2026, 7, 14);
      expect(Difficulty.forDate(date), Difficulty.forDate(date));
    });

    test('stays the same within a single 10-hour cycle', () {
      final start = DateTime.utc(2026, 7, 14);
      expect(Difficulty.forDate(start),
          Difficulty.forDate(start.add(const Duration(hours: 9))));
    });

    test('changes once a 10-hour cycle boundary is crossed', () {
      final start = DateTime.utc(2026, 7, 14);
      final tiers = {
        for (var i = 0; i < 3; i++)
          Difficulty.forDate(start.add(dailyCycleDuration * i)),
      };
      expect(tiers, Difficulty.values.toSet());
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

    test('tile value range is the same 1-10 spread on every tier', () {
      expect(Difficulty.easy.maxTileValue, 10);
      expect(Difficulty.medium.maxTileValue, 10);
      expect(Difficulty.hard.maxTileValue, 10);
    });

    test('Daily Rush countdown is shorter on harder tiers', () {
      expect(Difficulty.hard.rushDuration, const Duration(seconds: 10));
      expect(Difficulty.medium.rushDuration, const Duration(seconds: 12));
      expect(Difficulty.easy.rushDuration, const Duration(seconds: 15));
      expect(Difficulty.hard.rushDuration, lessThan(Difficulty.medium.rushDuration));
      expect(Difficulty.medium.rushDuration, lessThan(Difficulty.easy.rushDuration));
    });
  });
}
