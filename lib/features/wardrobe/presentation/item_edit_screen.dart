import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/photo_store.dart';
import '../../../core/widgets/palette_bar.dart';
import '../../outfits/data/outfit_repository.dart';
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
        _price.text = item.purchasePriceCents == null
            ? ''
            : (item.purchasePriceCents! / 100).toStringAsFixed(2);
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
    final path = await PhotoStore.save(picked);
    if (!mounted) return;
    setState(() => _photoPath = path);
    // Fill in colours automatically the first time; after that the user
    // decides (they may have fixed them by hand).
    if (_colors.isEmpty) await _detectColors(quiet: true);
  }

  Future<void> _detectColors({bool quiet = false}) async {
    final path = _photoPath;
    if (path == null) return;
    setState(() => _detecting = true);
    List<ItemColor> found;
    try {
      found = await detectItemColors(path);
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
            ),
            gap,
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
                      helperText: 'Used for cost-per-wear',
                    ),
                    validator: (v) {
                      final text = (v ?? '').trim().replaceAll(',', '.');
                      if (text.isEmpty) return null;
                      return double.tryParse(text) == null
                          ? 'Enter a number'
                          : null;
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

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.path,
    required this.onCamera,
    required this.onGallery,
  });

  final String? path;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

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
                : Image.file(File(path!), fit: BoxFit.cover),
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

  Future<void> _add(BuildContext context) async {
    final picked = await showColorPickerSheet(context);
    if (picked != null && !colors.contains(picked)) {
      onChanged([...colors, picked]);
    }
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
                label: Text(c.name),
                onDeleted: () => onChanged([...colors]..remove(c)),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Add colour'),
              onPressed: () => _add(context),
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
