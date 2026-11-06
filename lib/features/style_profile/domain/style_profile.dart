/// The user's personal style rules. Useful on its own as a reference, and
/// it is what keeps the AI coach's advice consistent with the user's look.
class StyleProfile {
  const StyleProfile({
    this.styleWords = '',
    this.palette = '',
    this.silhouettes = '',
    this.avoid = '',
    this.lifestyle = '',
    this.notes = '',
  });

  /// e.g. "minimal, relaxed, a little preppy"
  final String styleWords;

  /// e.g. "navy, cream, camel, olive; gold accents"
  final String palette;

  /// e.g. "straight-leg trousers, boxy knits, midi skirts"
  final String silhouettes;

  /// Things to steer away from: colours, cuts, fabrics.
  final String avoid;

  /// What the user's days look like: office, outdoors, kids, travel...
  final String lifestyle;
  final String notes;

  bool get isEmpty => [styleWords, palette, silhouettes, avoid, lifestyle, notes]
      .every((s) => s.trim().isEmpty);

  factory StyleProfile.fromRow(Map<String, Object?> row) => StyleProfile(
        styleWords: row['style_words'] as String? ?? '',
        palette: row['palette'] as String? ?? '',
        silhouettes: row['silhouettes'] as String? ?? '',
        avoid: row['avoid'] as String? ?? '',
        lifestyle: row['lifestyle'] as String? ?? '',
        notes: row['notes'] as String? ?? '',
      );

  Map<String, Object?> toRow() => {
        'style_words': styleWords,
        'palette': palette,
        'silhouettes': silhouettes,
        'avoid': avoid,
        'lifestyle': lifestyle,
        'notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      };
}
