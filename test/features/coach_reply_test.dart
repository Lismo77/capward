import 'package:capsule_wardrobe/features/coach/domain/coach_reply.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plain reply has no outfits', () {
    final r = parseCoachReply('Wear the navy sweater.');
    expect(r.text, 'Wear the navy sweater.');
    expect(r.outfits, isEmpty);
  });

  test('extracts ids and hides the block', () {
    final r = parseCoachReply('Try this.\n<outfit>3, 7,12</outfit>\n');
    expect(r.text, 'Try this.');
    expect(r.outfits, [
      [3, 7, 12]
    ]);
  });

  test('several outfits, junk and repeated ids', () {
    final r = parseCoachReply(
        'A\n<outfit>1,2</outfit>\nB\n<outfit>[4],x,4,5</outfit>\n<outfit>x</outfit>');
    expect(r.text, 'A\n\nB');
    expect(r.outfits, [
      [1, 2],
      [4, 5]
    ]);
  });

  test('hides an unfinished block', () {
    final r = parseCoachReply('Try this.\n<outfit>3,7');
    expect(r.text, 'Try this.');
    expect(r.outfits, isEmpty);
  });
}
