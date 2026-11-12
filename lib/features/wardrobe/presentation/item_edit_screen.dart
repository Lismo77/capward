import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/format.dart';
import '../../../core/photos/photo_rotation.dart';
import '../../../core/photos/photo_store.dart';
import '../../../core/widgets/palette_bar.dart';
import '../../outfits/data/outfit_repository.dart';
import '../../wear_log/data/wear_log_repository.dart';
import '../../wear_log/presentation/log_wear.dart';
import '../data/item_repository.dart';
import '../domain/item.dart';
import 'color_detection.dart';
import 'widgets/color_picker_sheet.dart';

/// Add or edit one item. Fully manual - AI photo tagging will plug in here
/// later as an optional "Fill in from photo" button (see docs/ROADMAP.md).
class ItemEditScreen extends ConsumerStatefulWidget {
  const ItemEditScreen({super.key, this.itemId});

  final int? itemId;

  @override
  ConsumerState<ItemEditScreen> createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends ConsumerState<ItemEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _material = TextEditingController();
  final _brand = TextEditingController();
  final _price = TextEditingController();
  final _notes = TextEditingController();

  ItemCategory _category = ItemCategory.top;
  List<ItemColor> _colors = [];
  bool _detecting = false;
  Set<Season> _seasons = {};
  int _formality = 3;
  ItemStatus _status = ItemStatus.active;
  String? _photoPath;

  /// Photos saved while this screen is open. Only these are safe to delete
  /// when replaced: the item's original photo stays until the user saves.
  final Set<String> _newPhotos = {};
  bool _rotating = false;
  DateTime? _purchaseDate;
  bool _loading = true;
  bool _saving = false;

  bool get _isNew => widget.itemId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_isNew) {
      final repo = await ref.read(itemRepositoryProvider.future);
      final item = await repo.byId(widget.itemId!);
      if (item != null) {
        _name.text = item.name;
        _colors = [...item.colors];
        _material.text = item.material ?? '';
        _brand.text = item.brand ?? '';
        _notes.text = item.notes ?? '';
        _price.text = switch (item.purchasePriceCents) {
          null => '',
          0 => '0',
          final cents => (cents / 100).toStringAsFixed(2),
        };
        _category = item.category;
        _seasons = {...item.seasons};
        _formality = item.formality;
        _status = item.status;
        _photoPath = item.photoPath;
        _purchaseDate = item.purchaseDate;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [_name, _material, _brand, _price, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    final store = ref.read(photoStoreProvider);
    final old = _photoPath;
    final path = await store.save(picked);
    _newPhotos.add(path);
    if (old != null && _newPhotos.remove(old)) await store.delete(old);
    if (!mounted) return;
    setState(() => _photoPath = path);
    // Fill in colours automatically the first time; after that the user
    // decides (they may have fixed them by hand).
    if (_colors.isEmpty) await _detectColors(quiet: true);
  }

  /// Saves a rotated copy of the photo. Rotation repeats until the user
  /// saves, so intermediate copies made on this screen are deleted.
  Future<void> _rotatePhoto() async {
    final old = _photoPath;
    if (old == null || _rotating) return;
    setState(() => _rotating = true);
    final store = ref.read(photoStoreProvider);
    try {
      final bytes = await store.read(old);
      if (bytes == null) throw const FormatException('Photo is missing');
      final rotated = await rotatePhotoClockwiseInBackground(bytes);
      final path =
          await store.saveBytes(rotated.bytes, extension: rotated.extension);
      _newPhotos.add(path);
      if (_newPhotos.remove(old)) await store.delete(old);
      if (mounted) setState(() => _photoPath = path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Couldn't rotate this photo")));
      }
    } finally {
      if (mounted) setState(() => _rotating = false);
    }
  }

  Future<void> _detectColors({bool quiet = false}) async {
    final path = _photoPath;
    if (path == null) return;
    setState(() => _detecting = true);
    List<ItemColor> found;
    try {
      final bytes = await ref.read(photoStoreProvider).read(path);
      found = bytes == null ? const [] : await detectItemColors(bytes);
    } catch (_) {
      found = const [];
    }
    if (!mounted) return;
    setState(() {
      _detecting = false;
      if (found.isNotEmpty) _colors = found;
    });
    if (found.isEmpty && !quiet) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Couldn't pick out colours. Add them by hand.")));
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    // Same as the colour sheet: don't jump back to the last text field.
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? now,
      firstDate: DateTime(1980),
      lastDate: now,
    );
    if (picked != null) setState(() => _purchaseDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final price = double.tryParse(_price.text.trim().replaceAll(',', '.'));
    final item = Item(
      id: widget.itemId,
      name: _name.text.trim(),
      category: _category,
      colors: _colors,
      material: _nullIfEmpty(_material.text),
      seasons: _seasons,
      formality: _formality,
      brand: _nullIfEmpty(_brand.text),
      purchasePriceCents: price == null ? null : (price * 100).round(),
      purchaseDate: _purchaseDate,
      photoPath: _photoPath,
      status: _status,
      notes: _nullIfEmpty(_notes.text),
    );

    final repo = await ref.read(itemRepositoryProvider.future);
    await repo.save(item);
    ref.invalidate(itemsProvider);
    ref.invalidate(outfitsProvider);
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this item?'),
        content: const Text(
            'This also removes it from outfits and capsules. To keep its '
            'history, set the status to Retired instead.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = await ref.read(itemRepositoryProvider.future);
    await repo.delete(widget.itemId!);
    ref.invalidate(itemsProvider);
    ref.invalidate(outfitsProvider);
    ref.invalidate(wearLogProvider);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    const gap = SizedBox(height: 16);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Add item' : 'Edit item'),
        actions: [
          if (!_isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: _delete,
            ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _PhotoPicker(
              path: _photoPath,
              onCamera: () => _pickPhoto(ImageSource.camera),
              onGallery: () => _pickPhoto(ImageSource.gallery),
              onRotate: _photoPath == null ? null : _rotatePhoto,
              rotating: _rotating,
            ),
            gap,
            if (!_isNew && _status != ItemStatus.wishlist) ...[
              _WearSummary(itemId: widget.itemId!),
              gap,
            ],
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Navy merino crew-neck',
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Give the item a name'
                  : null,
            ),
            gap,
            DropdownButtonFormField<ItemCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in ItemCategory.values)
                  DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: (c) => setState(() => _category = c ?? _category),
            ),
            gap,
            _ColorsEditor(
              colors: _colors,
              onChanged: (c) => setState(() => _colors = c),
              onDetect: _photoPath == null ? null : _detectColors,
              detecting: _detecting,
            ),
            gap,
            TextFormField(
              textCapitalization: TextCapitalization.sentences,
              controller: _material,
              decoration: const InputDecoration(
                labelText: 'Material',
                hintText: 'e.g. merino wool',
              ),
            ),
            gap,
            Text('Seasons', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final s in Season.values)
                  FilterChip(
                    label: Text(s.label),
                    selected: _seasons.contains(s),
                    onSelected: (on) => setState(() {
                      if (on) {
                        _seasons.add(s);
                      } else {
                        _seasons.remove(s);
                      }
                    }),
                  ),
              ],
            ),
            gap,
            Text('Formality: ${formalityLabels[_formality]}',
                style: theme.textTheme.labelLarge),
            Slider(
              value: _formality.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: formalityLabels[_formality],
              onChanged: (v) => setState(() => _formality = v.round()),
            ),
            TextFormField(
              textCapitalization: TextCapitalization.words,
              controller: _brand,
              decoration: const InputDecoration(labelText: 'Brand'),
            ),
            gap,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Price paid',
                      helperText: 'Blank if unknown, 0 if free or a gift',
                      helperMaxLines: 2,
                    ),
                    validator: (v) {
                      final text = (v ?? '').trim().replaceAll(',', '.');
                      if (text.isEmpty) return null;
                      final value = double.tryParse(text);
                      if (value == null) return 'Enter a number';
                      return value < 0 ? 'Enter 0 or more' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(_purchaseDate == null
                        ? 'Purchase date'
                        : _formatDate(_purchaseDate!)),
                    onPressed: _pickDate,
                  ),
                ),
              ],
            ),
            gap,
            DropdownButtonFormField<ItemStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                for (final s in ItemStatus.values)
                  DropdownMenuItem(value: s, child: Text(s.label)),
              ],
              onChanged: (s) => setState(() => _status = s ?? _status),
            ),
            gap,
            TextFormField(
              textCapitalization: TextCapitalization.sentences,
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Fit, care instructions, what it pairs with...',
              ),
              maxLines: 4,
              minLines: 2,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// Times worn, last worn and cost per wear, plus a one-tap wear log.
class _WearSummary extends ConsumerWidget {
  const _WearSummary({required this.itemId});

  final int itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(itemWearStatsProvider(itemId));
    final String text;
    if (stats == null) {
      text = '';
    } else if (stats.timesWorn == 0) {
      text = 'Not worn yet';
    } else {
      final cpw = stats.costPerWearCents;
      text = [
        stats.timesWorn == 1 ? 'Worn once' : 'Worn ${stats.timesWorn} times',
        'last worn ${inlineDate(stats.lastWornOn!, today: DateTime.now())}',
        if (cpw != null) '${formatCents(cpw)} per wear',
        if (stats.item.isFree) 'free or a gift',
      ].join(' · ');
    }
    return Row(
      children: [
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.event_available_outlined, size: 18),
          label: const Text('Wore this today'),
          onPressed: () => logItemsWorn(context, itemIds: [itemId]),
        ),
      ],
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.path,
    required this.onCamera,
    required this.onGallery,
    required this.onRotate,
    required this.rotating,
  });

  final String? path;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  /// Null when there is no photo to rotate.
  final VoidCallback? onRotate;
  final bool rotating;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 240,
            width: double.infinity,
            child: path == null
                ? ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: Icon(Icons.add_a_photo_outlined,
                        size: 48, color: scheme.outline),
                  )
                : StoredPhoto(
                    path!,
                    fallback: (_) => ColoredBox(
                      color: scheme.surfaceContainerHighest,
                      child: Icon(Icons.broken_image_outlined,
                          size: 48, color: scheme.outline),
                    ),
                  ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: onCamera,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Camera'),
            ),
            TextButton.icon(
              onPressed: onGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Gallery'),
            ),
            if (onRotate != null)
              TextButton.icon(
                onPressed: rotating ? null : onRotate,
                icon: rotating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.rotate_90_degrees_cw_outlined),
                label: const Text('Rotate'),
              ),
          ],
        ),
      ],
    );
  }
}

class _ColorsEditor extends StatelessWidget {
  const _ColorsEditor({
    required this.colors,
    required this.onChanged,
    required this.onDetect,
    required this.detecting,
  });

  final List<ItemColor> colors;
  final ValueChanged<List<ItemColor>> onChanged;

  /// Null when there is no photo to detect from.
  final VoidCallback? onDetect;
  final bool detecting;

  Future<void> _pick(BuildContext context) async {
    final picked = await showColorPickerSheet(context,
        selected: [for (final c in colors) c.name]);
    if (picked != null) onChanged(applyColorSelection(colors, picked));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Colours', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in colors)
              InputChip(
                avatar: ColorDot(color: c.value),
                label: Text(c.label),
                onDeleted: () => onChanged([...colors]..remove(c)),
              ),
            ActionChip(
              avatar: Icon(colors.isEmpty ? Icons.add : Icons.edit_outlined,
                  size: 18),
              label: Text(colors.isEmpty ? 'Add colours' : 'Edit colours'),
              onPressed: () => _pick(context),
            ),
            if (onDetect != null)
              ActionChip(
                avatar: detecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.colorize, size: 18),
                label: const Text('Detect from photo'),
                onPressed: detecting ? null : onDetect,
              ),
          ],
        ),
      ],
    );
  }
}

String? _nullIfEmpty(String s) => s.trim().isEmpty ? null : s.trim();

String _formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
