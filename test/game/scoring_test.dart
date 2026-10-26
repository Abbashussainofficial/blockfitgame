import 'package:block_fit/game/scoring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placement scores one point per cell', () {
    expect(Scoring.placementPoints(1), 1);
    expect(Scoring.placementPoints(9), 9);
  });

  test('line clears multiply by the number of lines', () {
    expect(Scoring.clearPoints(0, 1), 0);
    expect(Scoring.clearPoints(1, 1), 10);
    expect(Scoring.clearPoints(2, 1), 40); // 2 lines * 10 * x2
    expect(Scoring.clearPoints(3, 1), 90); // 3 lines * 10 * x3
  });

  test('combo streak multiplies clear points', () {
    expect(Scoring.clearPoints(1, 2), 20);
    expect(Scoring.clearPoints(2, 3), 120);
    // A streak of 0 never zeroes out a clear.
    expect(Scoring.clearPoints(1, 0), 10);
  });

  test('combo streak grows on clears and resets otherwise', () {
    expect(Scoring.nextComboStreak(0, 1), 1);
    expect(Scoring.nextComboStreak(1, 2), 2);
    expect(Scoring.nextComboStreak(4, 0), 0);
  });
}
