/// A coach reply split into the text to show and the outfits it suggested.
class CoachReply {
  const CoachReply(this.text, this.outfits);

  /// The reply without the machine-readable outfit blocks.
  final String text;

  /// Item ids of each suggested outfit, in the order they appeared.
  final List<List<int>> outfits;
}

// The coach ends a suggested outfit with `<outfit>3,7,12</outfit>`.
final _block = RegExp(r'<outfit>([^<]*)</outfit>', caseSensitive: false);

/// Pulls the outfit blocks out of [raw]. Ids that aren't numbers are ignored,
/// repeated ids are dropped, and blocks left with no ids are skipped.
/// A half-written block (no closing tag) is hidden too, but gives no outfit.
CoachReply parseCoachReply(String raw) {
  final outfits = <List<int>>[];
  for (final m in _block.allMatches(raw)) {
    final ids = <int>{
      for (final part in m.group(1)!.split(','))
        if (int.tryParse(part.trim().replaceAll(RegExp(r'[\[\]]'), ''))
            case final id?)
          id,
    }.toList();
    if (ids.isNotEmpty) outfits.add(ids);
  }
  final text = raw
      .replaceAll(_block, '')
      .replaceAll(RegExp(r'<outfit>[^<]*$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  return CoachReply(text, outfits);
}
