import 'package:flutter_test/flutter_test.dart';
import 'package:numberama/state/difficulty.dart';

void main() {
  group('Difficulty.forDate', () {
    test('is deterministic - the same date always yields the same tier', () {
      final date = DateTime.utc(2026, 7, 14);
      expect(Difficulty.forDate(date), Difficulty.forDate(date));
    });

    test('stays the same within a single 10-hour cycle', () {
      // Cycles are counted from the Unix epoch, not from midnight, so start
      // at the real beginning of a cycle rather than at a calendar day.
      final cycle = dailyCycleIndex(DateTime.utc(2026, 7, 14));
      final start = DateTime.fromMillisecondsSinceEpoch(
        cycle * dailyCycleDuration.inMilliseconds,
        isUtc: true,
      );
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

    test('Daily Rush countdown is a fixed 60 seconds on every tier', () {
      // Harder tiers get their pressure from pair distance and sum-pair
      // chance instead - see Difficulty.rushDuration.
      for (final tier in Difficulty.values) {
        expect(tier.rushDuration, const Duration(seconds: 60));
      }
    });
  });
}
