import '../../style_profile/domain/style_profile.dart';
import '../../wardrobe/domain/item.dart';

/// Builds the system prompt for the style coach: who it is, the user's style
/// rules, and a text inventory of what they own.
String buildCoachSystemPrompt({
  required StyleProfile profile,
  required List<Item> items,
}) {
  final owned = items.where((i) => i.status == ItemStatus.active).toList();
  final wishlist = items.where((i) => i.status == ItemStatus.wishlist).toList();
  final buf = StringBuffer()
    ..writeln('You are a personal stylist and capsule-wardrobe coach inside a '
        'wardrobe-tracking app. Help the user build a smaller, more '
        'versatile wardrobe with a consistent personal style.')
    ..writeln()
    ..writeln('How to help:')
    ..writeln('- Build outfits from items the user already owns first. '
        'Refer to items by their [id] and name.')
    ..writeln('- Recommend buying something only when it fills a real gap '
        '(it would create several new outfits or replace something worn '
        'out). Say why.')
    ..writeln('- Respect the style profile. If a request conflicts with it, '
        'point that out kindly.')
    ..writeln('- Explain the reasoning (colour, proportion, formality) '
        'briefly, so the user learns over time.')
    ..writeln('- Be concise and practical. Plain text, short lists.')
    ..writeln('- When you suggest an outfit made of the user\'s own items, '
        'end that suggestion with one line listing their ids, exactly like '
        '<outfit>3,7,12</outfit>. The app turns it into a button and hides '
        'the line, so never mention it. Use only ids of items in the '
        'wardrobe list below, one line per outfit, and leave it out for '
        'anything involving items they don\'t own.')
    ..writeln()
    ..writeln('## Style profile');

  if (profile.isEmpty) {
    buf.writeln('Not filled in yet. If it would help, ask the user a few '
        'questions about their style and suggest they save the answers in '
        'Settings > Style profile.');
  } else {
    void line(String label, String value) {
      if (value.trim().isNotEmpty) buf.writeln('- $label: ${value.trim()}');
    }

    line('Style words', profile.styleWords);
    line('Palette', profile.palette);
    line('Silhouettes', profile.silhouettes);
    line('Avoid', profile.avoid);
    line('Lifestyle', profile.lifestyle);
    line('Notes', profile.notes);
  }

  buf
    ..writeln()
    ..writeln('## Wardrobe (${owned.length} items in rotation)');
  if (owned.isEmpty) {
    buf.writeln('No items added yet.');
  } else {
    for (final item in owned) {
      buf.writeln(item.describeForAi());
    }
  }

  if (wishlist.isNotEmpty) {
    buf
      ..writeln()
      ..writeln('## Wishlist (not owned yet)');
    for (final item in wishlist) {
      buf.writeln(item.describeForAi());
    }
  }

  return buf.toString();
}
