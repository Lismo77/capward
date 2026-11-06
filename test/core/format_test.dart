import 'package:capsule_wardrobe/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 11, 6, 15, 30);

  test('friendlyDate', () {
    expect(friendlyDate(DateTime(2026, 11, 6), today: today), 'Today');
    expect(friendlyDate(DateTime(2026, 11, 5, 23), today: today), 'Yesterday');
    expect(friendlyDate(DateTime(2026, 3, 1), today: today), '1 Mar');
    expect(friendlyDate(DateTime(2025, 12, 31), today: today), '31 Dec 2025');
  });

  test('yesterday works across a month boundary', () {
    expect(friendlyDate(DateTime(2026, 2, 28), today: DateTime(2026, 3, 1)),
        'Yesterday');
  });

  test('inlineDate lower-cases only today and yesterday', () {
    expect(inlineDate(DateTime(2026, 11, 6), today: today), 'today');
    expect(inlineDate(DateTime(2026, 11, 5), today: today), 'yesterday');
    expect(inlineDate(DateTime(2026, 11, 2), today: today), '2 Nov');
  });

  test('weekdayDate', () {
    expect(weekdayDate(DateTime(2026, 11, 6)), 'Fri 6 Nov');
    expect(weekdayDate(DateTime(2026, 11, 9)), 'Mon 9 Nov');
  });

  test('isoDate and formatCents', () {
    expect(isoDate(DateTime(2026, 1, 9)), '2026-01-09');
    expect(formatCents(1240), '12.40');
    expect(formatCents(5), '0.05');
    expect(formatCents(-150), '-1.50');
  });
}
