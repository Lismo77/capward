import 'package:gansey/features/feedback/domain/feedback_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const info = DeviceInfo(
    appVersion: '0.4.0 (4)',
    platform: 'android',
    isWeb: false,
    aiEnabled: true,
  );

  test('subject gets a kind prefix, even with no title', () {
    const bug = FeedbackReport(
        kind: FeedbackKind.bug, title: ' Crash on save ', details: '');
    expect(bug.subject, 'Bug: Crash on save');
    const idea =
        FeedbackReport(kind: FeedbackKind.idea, title: '', details: '');
    expect(idea.subject, 'Idea:');
  });

  test('body has details, then device info only when included', () {
    const withInfo = FeedbackReport(
        kind: FeedbackKind.bug,
        title: 't',
        details: 'It broke',
        deviceInfo: info);
    expect(withInfo.body, contains('It broke'));
    expect(withInfo.body, contains('App version: 0.4.0 (4)'));
    expect(withInfo.body, contains('AI features: on'));

    const without =
        FeedbackReport(kind: FeedbackKind.bug, title: 't', details: 'It broke');
    expect(without.body, 'It broke');
  });

  test('web builds are labelled', () {
    const web = DeviceInfo(
        appVersion: '0.4.0', platform: 'iOS', isWeb: true, aiEnabled: false);
    expect(web.text, contains('iOS (web version)'));
    expect(web.text, contains('AI features: off'));
  });

  test('github link carries title, body and label, encoded', () {
    const report = FeedbackReport(
        kind: FeedbackKind.idea,
        title: 'Dark & light',
        details: 'Line one\nLine two #1');
    final uri = report.githubIssueUri;
    expect(uri.host, 'github.com');
    expect(uri.path, '/Lismo77/gansey/issues/new');
    expect(uri.queryParameters['title'], 'Idea: Dark & light');
    expect(uri.queryParameters['body'], 'Line one\nLine two #1');
    expect(uri.queryParameters['labels'], 'enhancement');
  });

  test('long bodies are cut in links but not in the copied text', () {
    final report = FeedbackReport(
        kind: FeedbackKind.bug,
        title: 't',
        details: 'x' * (maxLinkBodyLength + 500));
    expect(report.body.length, maxLinkBodyLength + 500);
    final linked = report.githubIssueUri.queryParameters['body']!;
    expect(linked, startsWith('x' * maxLinkBodyLength));
    expect(linked, contains('Cut short'));
  });

  test('mailto is hidden until a contact address is set', () {
    const report =
        FeedbackReport(kind: FeedbackKind.bug, title: 't', details: 'd');
    // Keep this in step with the placeholder in feedback_report.dart.
    expect(report.mailtoUri, feedbackEmail.isEmpty ? isNull : isNotNull);
  });
}
