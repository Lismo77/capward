import 'item_color.dart';

export 'item_color.dart';

enum ItemCategory {
  top,
  bottom,
  dress,
  outerwear,
  shoes,

  /// Its own category because only one is worn at a time.
  hat,
  accessory,
  bag,
  other;

  String get label => _titleCase(name);
}

enum Season {
  spring,
  summer,
  autumn,
  winter;

  String get label => _titleCase(name);

  /// The season on [day], by month (meteorological seasons: spring is
  /// March to May in the north, September to November in the south).
  static Season on(DateTime day, {bool southernHemisphere = false}) {
    final north = switch (day.month) {
      3 || 4 || 5 => Season.spring,
      6 || 7 || 8 => Season.summer,
      9 || 10 || 11 => Season.autumn,
      _ => Season.winter,
    };
    return southernHemisphere ? values[(north.index + 2) % 4] : north;
  }
}

enum ItemStatus {
  /// In regular rotation.
  active,

  /// Owned but put away (off-season, stored).
  stored,

  /// Not owned yet - something the user is considering.
  wishlist,

  /// Donated, sold or worn out. Kept for history and stats.
  retired;

  String get label => _titleCase(name);
}

const formalityLabels = {
  1: 'Very casual',
  2: 'Casual',
  3: 'Smart casual',
  4: 'Business',
  5: 'Formal',
};

class Item {
  const Item({
    this.id,
    required this.name,
    required this.category,
    this.colors = const [],
    this.material,
    this.seasons = const {},
    this.formality = 3,
    this.brand,
    this.purchasePriceCents,
    this.purchaseDate,
    this.photoPath,
    this.status = ItemStatus.active,
    this.notes,
    this.createdAt,
  });

  final int? id;
  final String name;
  final ItemCategory category;
  final List<ItemColor> colors;
  final String? material;
  final Set<Season> seasons;

  /// 1 (very casual) to 5 (formal).
  final int formality;
  final String? brand;

  /// What the user paid. Null means unknown; 0 means it was free or a gift.
  final int? purchasePriceCents;
  final DateTime? purchaseDate;
  final String? photoPath;
  final ItemStatus status;
  final String? notes;

  /// When the item was added to the app. Read from the database only; new
  /// rows get it from the column default.
  final DateTime? createdAt;

  /// Free or a gift: a price of 0, as opposed to no price entered.
  bool get isFree => purchasePriceCents == 0;

  Map<String, Object?> toRow() => {
        'id': id,
        'name': name,
        'category': category.name,
        'colors': colors.map((c) => c.name).join(','),
        'swatches': ItemColor.encodeList(colors),
        'material': material,
        'seasons': _sortedSeasons.map((s) => s.name).join(','),
        'formality': formality,
        'brand': brand,
        'purchase_price_cents': purchasePriceCents,
        'purchase_date': purchaseDate?.toIso8601String().substring(0, 10),
        'photo_path': photoPath,
        'status': status.name,
        'notes': notes,
      };

  factory Item.fromRow(Map<String, Object?> row) {
    final date = row['purchase_date'] as String?;
    return Item(
      id: row['id'] as int?,
      name: row['name'] as String,
      category: _readCategory(row['category']),
      colors: _readColors(row),
      material: row['material'] as String?,
      seasons: _splitList(row['seasons'] as String?)
          .map((s) => Season.values.asNameMap()[s])
          .whereType<Season>()
          .toSet(),
      formality: row['formality'] as int? ?? 3,
      brand: row['brand'] as String?,
      purchasePriceCents: row['purchase_price_cents'] as int?,
      purchaseDate: date == null ? null : DateTime.tryParse(date),
      photoPath: row['photo_path'] as String?,
      status: ItemStatus.values.asNameMap()[row['status']] ?? ItemStatus.active,
      notes: row['notes'] as String?,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
    );
  }

  /// One compact line per item for AI prompts. Text only - no photos - so
  /// requests stay cheap and private.
  String describeForAi() {
    final parts = <String>[category.label.toLowerCase()];
    if (colors.isNotEmpty) {
      parts.add('colors: ${colors.map((c) => c.name).join(', ')}');
    }
    if ((material ?? '').isNotEmpty) parts.add('material: $material');
    if (seasons.isNotEmpty) {
      parts.add('seasons: ${_sortedSeasons.map((s) => s.name).join(', ')}');
    }
    parts.add('formality $formality/5');
    return '[$id] $name - ${parts.join('; ')}';
  }

  List<Season> get _sortedSeasons =>
      seasons.toList()..sort((a, b) => a.index.compareTo(b.index));
}

/// What the wardrobe grid shows. Retired items are kept out of the normal
/// view and shown on their own when [retired] is true. [category] narrows
/// either view.
List<Item> wardrobeView(
  Iterable<Item> items, {
  ItemCategory? category,
  bool retired = false,
}) =>
    items
        .where((i) => (i.status == ItemStatus.retired) == retired)
        .where((i) => category == null || i.category == category)
        .toList();

/// Activewear was a category until v6, which made those items tops (where
/// outfits already put them). Backups made before then still say activewear.
ItemCategory _readCategory(Object? name) {
  if (name == 'activewear') return ItemCategory.top;
  return ItemCategory.values.asNameMap()[name] ?? ItemCategory.other;
}

/// Rows saved before v2 only have colour names; give those preset swatches.
List<ItemColor> _readColors(Map<String, Object?> row) {
  final swatches = ItemColor.decodeList(row['swatches'] as String?);
  if (swatches.isNotEmpty) return swatches;
  return _splitList(row['colors'] as String?).map(ItemColor.named).toList();
}

List<String> _splitList(String? value) => (value ?? '')
    .split(',')
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();

String _titleCase(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
