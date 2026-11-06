import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/style_profile_repository.dart';
import '../domain/style_profile.dart';

class StyleProfileScreen extends ConsumerStatefulWidget {
  const StyleProfileScreen({super.key});

  @override
  ConsumerState<StyleProfileScreen> createState() => _StyleProfileScreenState();
}

class _StyleProfileScreenState extends ConsumerState<StyleProfileScreen> {
  final _styleWords = TextEditingController();
  final _palette = TextEditingController();
  final _silhouettes = TextEditingController();
  final _avoid = TextEditingController();
  final _lifestyle = TextEditingController();
  final _notes = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await ref.read(styleProfileProvider.future);
    _styleWords.text = p.styleWords;
    _palette.text = p.palette;
    _silhouettes.text = p.silhouettes;
    _avoid.text = p.avoid;
    _lifestyle.text = p.lifestyle;
    _notes.text = p.notes;
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [
      _styleWords,
      _palette,
      _silhouettes,
      _avoid,
      _lifestyle,
      _notes
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final repo = await ref.read(styleProfileRepositoryProvider.future);
    await repo.save(StyleProfile(
      styleWords: _styleWords.text.trim(),
      palette: _palette.text.trim(),
      silhouettes: _silhouettes.text.trim(),
      avoid: _avoid.text.trim(),
      lifestyle: _lifestyle.text.trim(),
      notes: _notes.text.trim(),
    ));
    ref.invalidate(styleProfileProvider);
    if (mounted) context.pop();
  }

  Widget _field(TextEditingController c, String label, String hint) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextField(
          controller: c,
          decoration: InputDecoration(labelText: label, hintText: hint),
          minLines: 1,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Style profile'),
        actions: [
          TextButton(
              onPressed: _loading ? null : _save, child: const Text('Save')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Write down the rules of your style. They keep your '
                  'capsule consistent, and they guide the AI coach if you '
                  'turn it on.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _field(_styleWords, 'Style in a few words',
                    'minimal, relaxed, a little preppy'),
                _field(_palette, 'Colour palette',
                    'navy, cream, camel, olive; gold accents'),
                _field(_silhouettes, 'Shapes and silhouettes',
                    'straight-leg trousers, boxy knits'),
                _field(_avoid, 'Avoid', 'bright orange, skinny fits, polyester'),
                _field(_lifestyle, 'Lifestyle',
                    'hybrid office job, weekend hikes, cold winters'),
                _field(_notes, 'Other notes', ''),
              ],
            ),
    );
  }
}
