// In-app feedback (bug reports / feature requests) + update check + repo link.
//
// How it works (Matt's choice, 2026-11-05): the app files a GitHub Issue on
// cartchai/iptv-player straight from inside TVmagic — one tap, no jumping
// back to chat. Muse picks new issues up from GitHub on a schedule and works
// on them.
//
// The GitHub token is a minimal fine-grained PAT ("tvmagic-issues": Issues
// read+write ONLY, on cartchai/iptv-player ONLY). It is NOT in source and
// NOT in the public repo — it is passed at build time with
//   --dart-define=GITHUB_ISSUES_TOKEN=<token>
// (Codemagic holds it as a secure environment variable) and read here with
// String.fromEnvironment. If the define is missing (e.g. a local dev build),
// the form falls back to opening the GitHub issues page in the browser
// instead of submitting in-app.
//
// The update check reads the public GitHub Releases API (no token needed):
// it compares the latest release tag to the installed version and offers
// to download a newer APK. Every shipped version should also get a GitHub
// Release with the APK attached, so the repo link below always has older
// versions to grab.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'state/app_state.dart';
import 'theme.dart';

/// App version — keep in sync with pubspec.yaml `version: 0.1.0+1`.
const String kAppVersion = '0.2.0';

/// GitHub repo that hosts TVmagic (code, issues, releases).
const String kRepoOwner = 'cartchai';
const String kRepoName = 'iptv-player';
const String kRepoUrl = 'https://github.com/$kRepoOwner/$kRepoName';
const String kIssuesUrl = '$kRepoUrl/issues';
const String kReleasesApiUrl =
    'https://api.github.com/repos/$kRepoOwner/$kRepoName/releases/latest';
const String kIssuesApiUrl =
    'https://api.github.com/repos/$kRepoOwner/$kRepoName/issues';

/// The minimal issues token, injected at build time with
/// --dart-define=GITHUB_ISSUES_TOKEN=... . Empty when not provided.
const String kIssuesToken =
    String.fromEnvironment('GITHUB_ISSUES_TOKEN', defaultValue: '');

bool get kCanFileIssuesInApp => kIssuesToken.isNotEmpty;

/// Bug vs feature request — the kind of feedback being filed.
enum FeedbackKind { bug, feature }

extension on FeedbackKind {
  String get label => this == FeedbackKind.bug ? 'Bug report' : 'Feature request';
  String get githubLabel => this == FeedbackKind.bug ? 'bug' : 'enhancement';
}

/// Tab names for the auto-attached "where were you" line.
const List<String> kTabNames = ['Live', 'Guide', 'Movies', 'Series', 'Settings'];

/// Build the GitHub issue body: the user's words first, then the
/// auto-attached diagnostics (app version, platform, screen, current tab).
/// Pure function — unit-tested.
String buildIssueBody({
  required FeedbackKind kind,
  required String title,
  required String description,
  required String appVersion,
  required String platform,
  required String osVersion,
  required String screenSize,
  required String currentTab,
}) {
  final buffer = StringBuffer();
  buffer.writeln(description.trim());
  buffer.writeln();
  buffer.writeln('---');
  buffer.writeln('Reported from inside TVmagic ($appVersion).');
  buffer.writeln('Type: ${kind.label}');
  buffer.writeln('Screen: $currentTab');
  buffer.writeln('Device: $platform ($osVersion), $screenSize');
  return buffer.toString();
}

/// Compare two semantic versions ("0.1.0" vs "v0.2.0"). Returns true when
/// [latest] is newer than [current]. Leading "v" is ignored; missing parts
/// count as 0. Pure function — unit-tested.
bool isNewerVersion(String latest, String current) {
  List<int> parse(String v) {
    final clean = v.trim().replaceFirst(RegExp(r'^v'), '');
    return clean.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  }

  final l = parse(latest);
  final c = parse(current);
  final len = l.length > c.length ? l.length : c.length;
  for (var i = 0; i < len; i++) {
    final lv = i < l.length ? l[i] : 0;
    final cv = i < c.length ? c[i] : 0;
    if (lv != cv) return lv > cv;
  }
  return false;
}

/// File a GitHub issue. Returns the created issue's web URL on success.
/// Throws on network failure, missing token, or a non-201 response.
/// [client] is injectable so tests can pass a mock.
Future<String> fileIssue({
  required FeedbackKind kind,
  required String title,
  required String description,
  required String body,
  http.Client? client,
}) async {
  if (kIssuesToken.isEmpty) {
    throw StateError('In-app issue filing is not configured in this build.');
  }
  final httpClient = client ?? http.Client();
  final response = await httpClient.post(
    Uri.parse(kIssuesApiUrl),
    headers: {
      'Authorization': 'Bearer $kIssuesToken',
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'title': '[${kind.label}] $title',
      'body': body,
      'labels': [kind.githubLabel],
    }),
  );
  if (response.statusCode != 201) {
    throw HttpException(
      'GitHub returned ${response.statusCode}: ${response.body}',
      uri: Uri.parse(kIssuesApiUrl),
    );
  }
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  return (data['html_url'] as String?) ?? kIssuesUrl;
}

/// A GitHub release, as returned by the releases/latest endpoint.
class ReleaseInfo {
  const ReleaseInfo({
    required this.tag,
    required this.pageUrl,
    required this.apkUrl,
  });
  final String tag;
  final String pageUrl;
  final String apkUrl;
}

/// Fetch the latest GitHub release. Returns null when the repo has no
/// releases yet (GitHub answers 404). Throws on network failure.
/// [client] is injectable so tests can pass a mock.
Future<ReleaseInfo?> fetchLatestRelease({http.Client? client}) async {
  final httpClient = client ?? http.Client();
  final response = await httpClient.get(
    Uri.parse(kReleasesApiUrl),
    headers: {'Accept': 'application/vnd.github+json'},
  );
  if (response.statusCode == 404) return null;
  if (response.statusCode != 200) {
    throw HttpException(
      'GitHub returned ${response.statusCode}',
      uri: Uri.parse(kReleasesApiUrl),
    );
  }
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final tag = (data['tag_name'] as String?) ?? '';
  final pageUrl = (data['html_url'] as String?) ?? kRepoUrl;
  String apkUrl = '';
  final assets = (data['assets'] as List<dynamic>?) ?? const [];
  for (final asset in assets) {
    final name = (asset as Map<String, dynamic>)['name'] as String? ?? '';
    if (name.toLowerCase().endsWith('.apk')) {
      apkUrl = asset['browser_download_url'] as String? ?? '';
      break;
    }
  }
  return ReleaseInfo(tag: tag, pageUrl: pageUrl, apkUrl: apkUrl);
}

/// Open a URL in the browser. Returns false when the URL cannot be opened.
Future<bool> openUrl(String url) async {
  final uri = Uri.parse(url);
  if (!await canLaunchUrl(uri)) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// The feedback form page: pick Bug / Feature, write a title and details,
/// submit. Auto-attaches app version, platform, screen size and current tab.
class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key, this.initialKind = FeedbackKind.bug});
  final FeedbackKind initialKind;

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  late FeedbackKind _kind = widget.initialKind;
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  String get _currentTabName {
    final tab = context.read<AppState>().currentTab;
    return (tab >= 0 && tab < kTabNames.length) ? kTabNames[tab] : 'Unknown';
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final description = _descController.text.trim();
    if (title.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a title and a few details first.')),
      );
      return;
    }
    if (!kCanFileIssuesInApp) {
      // No token in this build — fall back to the browser issues page.
      final opened = await openUrl(kIssuesUrl);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the issues page.')),
        );
      }
      return;
    }
    setState(() => _sending = true);
    try {
      final size = MediaQuery.sizeOf(context);
      final body = buildIssueBody(
        kind: _kind,
        title: title,
        description: description,
        appVersion: kAppVersion,
        platform: Platform.operatingSystem,
        osVersion: Platform.operatingSystemVersion,
        screenSize: '${size.width.toInt()}x${size.height.toInt()} dp',
        currentTab: _currentTabName,
      );
      final issueUrl = await fileIssue(
        kind: _kind,
        title: title,
        description: description,
        body: body,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sent — thank you. I\'ll take a look.')),
      );
      // Offer the filed issue so the user can see it on GitHub.
      await openUrl(issueUrl);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send that: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report a bug / Request a feature')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<FeedbackKind>(
            segments: const [
              ButtonSegment(
                value: FeedbackKind.bug,
                icon: Icon(Icons.bug_report),
                label: Text('Bug'),
              ),
              ButtonSegment(
                value: FeedbackKind.feature,
                icon: Icon(Icons.lightbulb_outline),
                label: Text('Feature'),
              ),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('feedback-title'),
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'Short summary — e.g. EPG jumps when I fold the phone',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('feedback-description'),
            controller: _descController,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'What happened / what do you want?',
              hintText: 'Steps to reproduce a bug, or what the feature should do.',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Sent as an issue on the TVmagic repo. Your app version, device, '
            'screen size and current tab are attached automatically.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _sending ? null : _submit,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(_sending
                ? 'Sending…'
                : (kCanFileIssuesInApp ? 'Send report' : 'Open issues on GitHub')),
          ),
        ],
      ),
    );
  }
}

/// Check for a newer TVmagic release and show the result in a dialog.
/// Call from a Settings tile. Pure version logic lives in [isNewerVersion].
Future<void> checkForUpdates(BuildContext context) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('Checking for updates…'),
        ],
      ),
    ),
  );
  ReleaseInfo? release;
  Object? error;
  try {
    release = await fetchLatestRelease();
  } catch (e) {
    error = e;
  }
  if (!context.mounted) return;
  Navigator.of(context).pop(); // dismiss the progress dialog
  if (error != null) {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Could not check'),
        content: Text('The update check failed: $error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;
  }
  if (release == null || release.tag.isEmpty) {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('No releases yet'),
        content: const Text(
          'There are no GitHub releases yet — this version was delivered '
          'directly. New versions will appear here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;
  }
  if (!isNewerVersion(release.tag, kAppVersion)) {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('You\'re up to date'),
        content: Text('TVmagic $kAppVersion is the latest release.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;
  }
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('TVmagic ${release!.tag} is available'),
      content: Text(
        'You have $kAppVersion. A newer release is ready on GitHub.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Later'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            if (release!.apkUrl.isNotEmpty) {
              openUrl(release.apkUrl);
            } else {
              openUrl(release.pageUrl);
            }
          },
          child: const Text('Download'),
        ),
      ],
    ),
  );
}
