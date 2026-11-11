import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../ai/ai_providers.dart';
import '../../../core/app_version.dart';
import '../domain/feedback_report.dart';

/// Lets a tester write up a bug or idea. Nothing is sent from here: the app
/// opens a prefilled GitHub issue or email draft for the user to review.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _title = TextEditingController();
  final _details = TextEditingController();
  FeedbackKind _kind = FeedbackKind.bug;
  bool _includeDeviceInfo = true;

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    super.dispose();
  }

  DeviceInfo get _deviceInfo => DeviceInfo(
        appVersion: ref.read(appVersionProvider).valueOrNull ?? 'unknown',
        platform: defaultTargetPlatform.name,
        isWeb: kIsWeb,
        aiEnabled: ref.read(aiSettingsProvider).valueOrNull?.enabled ?? false,
      );

  FeedbackReport get _report => FeedbackReport(
        kind: _kind,
        title: _title.text,
        details: _details.text,
        deviceInfo: _includeDeviceInfo ? _deviceInfo : null,
      );

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Returns the report, or says what is missing.
  FeedbackReport? _checked() {
    final report = _report;
    if (report.isEmpty) {
      _say('Write a few words first.');
      return null;
    }
    return report;
  }

  Future<void> _open(Uri uri, {required String failure}) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Fall through to the message below.
    }
    _say(failure);
  }

  Future<void> _github() async {
    final report = _checked();
    if (report == null) return;
    await _open(report.githubIssueUri,
        failure: 'Could not open the browser. Try "Copy text" instead.');
  }

  Future<void> _email() async {
    final report = _checked();
    final uri = report?.mailtoUri;
    if (uri == null) return;
    await _open(uri,
        failure: 'Could not open a mail app. Try "Copy text" instead.');
  }

  Future<void> _copy() async {
    final report = _checked();
    if (report == null) return;
    await Clipboard.setData(
        ClipboardData(text: '${report.subject}\n\n${report.body}'));
    _say('Copied');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canEmail = feedbackEmail.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Report a bug or idea')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<FeedbackKind>(
            segments: [
              for (final k in FeedbackKind.values)
                ButtonSegment(value: k, label: Text(k.label)),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Short summary',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _details,
            minLines: 5,
            maxLines: 12,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              labelText: 'Details',
              alignLabelWithHint: true,
              helperText: _kind.detailsHint,
              helperMaxLines: 3,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _includeDeviceInfo,
            onChanged: (v) => setState(() => _includeDeviceInfo = v ?? true),
            title: const Text('Include app version and platform'),
            subtitle: const Text('No wardrobe data, photos or API keys.'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _github,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open on GitHub'),
          ),
          if (canEmail) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _email,
              icon: const Icon(Icons.email_outlined),
              label: const Text('Send by email'),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _copy,
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copy text'),
          ),
          const SizedBox(height: 16),
          Text(
            'Nothing is sent from the app. These buttons open a draft in '
            'your browser or mail app, and you press send there. GitHub '
            'needs an account${canEmail ? ', so email is there if you '
                'don\'t have one' : ''}. Reports are public on GitHub.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
