/// Where tester reports go. There is no app server (product rule 2), so the
/// app only builds a link or message for the user to review and send
/// themselves.
library;

const issuesNewUrl = 'https://github.com/Lismo77/gansey/issues/new';

/// Public contact address for testers without a GitHub account. When empty,
/// the "Send by email" button is hidden.
const feedbackEmail = 'ganseyapp@gmail.com';

/// Browsers and mail apps reject very long links, so the body is cut to this
/// many characters when it goes into a link. "Copy text" keeps all of it.
const maxLinkBodyLength = 4000;

enum FeedbackKind {
  bug(
    label: 'Bug',
    titlePrefix: 'Bug: ',
    githubLabel: 'bug',
    detailsHint: 'What happened, and what did you expect? '
        'If you can, list the steps to make it happen again.',
  ),
  idea(
    label: 'Idea',
    titlePrefix: 'Idea: ',
    githubLabel: 'enhancement',
    detailsHint: 'What would you like the app to do, and why?',
  );

  const FeedbackKind({
    required this.label,
    required this.titlePrefix,
    required this.githubLabel,
    required this.detailsHint,
  });

  final String label;
  final String titlePrefix;
  final String githubLabel;
  final String detailsHint;
}

/// Non-identifying facts that help reproduce a bug. Nothing from the user's
/// wardrobe, style profile or AI provider (including the key) is included.
class DeviceInfo {
  const DeviceInfo({
    required this.appVersion,
    required this.platform,
    required this.isWeb,
    required this.aiEnabled,
  });

  final String appVersion;

  /// e.g. 'android', 'iOS'.
  final String platform;
  final bool isWeb;
  final bool aiEnabled;

  String get text => [
        '- App version: $appVersion',
        '- Platform: $platform${isWeb ? ' (web version)' : ''}',
        '- AI features: ${aiEnabled ? 'on' : 'off'}',
      ].join('\n');
}

class FeedbackReport {
  const FeedbackReport({
    required this.kind,
    required this.title,
    required this.details,
    this.deviceInfo,
  });

  final FeedbackKind kind;
  final String title;
  final String details;

  /// Null when the user chose not to include it.
  final DeviceInfo? deviceInfo;

  bool get isEmpty => title.trim().isEmpty && details.trim().isEmpty;

  String get subject {
    final t = title.trim();
    return t.isEmpty ? kind.titlePrefix.trim() : '${kind.titlePrefix}$t';
  }

  /// The full message, for "Copy text".
  String get body {
    final parts = <String>[
      if (details.trim().isNotEmpty) details.trim(),
      if (deviceInfo != null) '**Device info**\n${deviceInfo!.text}',
    ];
    return parts.join('\n\n');
  }

  String get _linkBody => body.length <= maxLinkBodyLength
      ? body
      : '${body.substring(0, maxLinkBodyLength)}\n\n'
          '[Cut short. Paste the rest here.]';

  /// A prefilled "new issue" page. The user reviews it and presses submit on
  /// GitHub, so nothing is sent until they do.
  Uri get githubIssueUri => Uri.parse(issuesNewUrl).replace(
        queryParameters: {
          'title': subject,
          'body': _linkBody,
          'labels': kind.githubLabel,
        },
      );

  /// A prefilled message for the user's mail app, or null when no contact
  /// address is set.
  Uri? get mailtoUri {
    if (feedbackEmail.isEmpty) return null;
    // Uri.queryParameters would encode spaces as '+', which mail apps show
    // literally, so build the query with %20.
    final query = {'subject': subject, 'body': _linkBody}
        .entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return Uri.parse('mailto:$feedbackEmail?$query');
  }
}
