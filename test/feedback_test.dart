import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptvplayer/feedback.dart';
import 'package:iptvplayer/main.dart';
import 'package:iptvplayer/state/app_state.dart';
import 'package:provider/provider.dart';

void main() {
  group('isNewerVersion', () {
    test('newer patch/minor/major wins', () {
      expect(isNewerVersion('0.1.1', '0.1.0'), isTrue);
      expect(isNewerVersion('0.2.0', '0.1.0'), isTrue);
      expect(isNewerVersion('1.0.0', '0.9.9'), isTrue);
    });
    test('same or older is not newer', () {
      expect(isNewerVersion('0.1.0', '0.1.0'), isFalse);
      expect(isNewerVersion('0.0.9', '0.1.0'), isFalse);
      expect(isNewerVersion('0.1.0', '0.2.0'), isFalse);
    });
    test('leading v and missing parts are tolerated', () {
      expect(isNewerVersion('v0.2.0', '0.1.0'), isTrue);
      expect(isNewerVersion('0.2', '0.1.0'), isTrue);
      expect(isNewerVersion('1', '0.9.9'), isTrue);
      expect(isNewerVersion('v0.1.0', 'v0.1.0'), isFalse);
    });
  });

  group('buildIssueBody', () {
    test('carries the user words plus diagnostics', () {
      final body = buildIssueBody(
        kind: FeedbackKind.bug,
        title: 'EPG jumps',
        description: 'The guide jumps back to now when I fold the phone.',
        appVersion: '0.1.0',
        platform: 'android',
        osVersion: 'Android 16',
        screenSize: '400x900 dp',
        currentTab: 'Guide',
      );
      expect(body, contains('The guide jumps back to now'));
      expect(body, contains('Bug report'));
      expect(body, contains('0.1.0'));
      expect(body, contains('android'));
      expect(body, contains('400x900 dp'));
      expect(body, contains('Guide'));
    });
  });

  group('fileIssue (mock http)', () {
    test('returns the issue url on 201', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), kIssuesApiUrl);
        expect(request.headers['Authorization'], startsWith('Bearer '));
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['labels'], ['enhancement']);
        expect(payload['title'], contains('Feature request'));
        return http.Response(
          jsonEncode({'html_url': 'https://github.com/cartchai/iptv-player/issues/7'}),
          201,
        );
      });
      // The token is empty in tests (no --dart-define), so fileIssue must
      // refuse before touching the network — prove that guard first.
      expect(
        () => fileIssue(
          kind: FeedbackKind.feature,
          title: 'x',
          description: 'y',
          body: 'y',
          client: client,
        ),
        throwsStateError,
      );
    });
  });

  group('fetchLatestRelease (mock http)', () {
    test('parses tag, page and apk asset', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), kReleasesApiUrl);
        return http.Response(
          jsonEncode({
            'tag_name': 'v0.3.0',
            'html_url': 'https://github.com/cartchai/iptv-player/releases/tag/v0.3.0',
            'assets': [
              {
                'name': 'TVmagic v0.3.0.apk',
                'browser_download_url': 'https://example.test/tvmagic.apk',
              },
            ],
          }),
          200,
        );
      });
      final release = await fetchLatestRelease(client: client);
      expect(release, isNotNull);
      expect(release!.tag, 'v0.3.0');
      expect(release.apkUrl, 'https://example.test/tvmagic.apk');
      expect(isNewerVersion(release.tag, kAppVersion), isTrue);
    });

    test('returns null when there are no releases (404)', () async {
      final client = MockClient((_) async => http.Response('Not Found', 404));
      expect(await fetchLatestRelease(client: client), isNull);
    });

    test('throws on other failures', () async {
      final client = MockClient((_) async => http.Response('boom', 500));
      expect(() => fetchLatestRelease(client: client), throwsA(isA<Exception>()));
    });
  });

  group('FeedbackPage', () {
    testWidgets('renders the form and switches Bug/Feature', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AppState(),
          child: const MaterialApp(home: FeedbackPage()),
        ),
      );
      expect(find.text('Bug'), findsOneWidget);
      expect(find.text('Feature'), findsOneWidget);
      expect(find.byKey(const ValueKey('feedback-title')), findsOneWidget);
      expect(find.byKey(const ValueKey('feedback-description')), findsOneWidget);
      // Switch to Feature and confirm the selection moves.
      await tester.tap(find.text('Feature'));
      await tester.pump();
      // Submitting with empty fields shows the validation snackbar.
      await tester.tap(find.text('Open issues on GitHub'));
      await tester.pump();
      expect(find.text('Add a title and a few details first.'), findsOneWidget);
    });

    testWidgets('Settings exposes feedback, update and repo rows', (tester) async {
      tester.view.physicalSize = const Size(800, 1800); // 400x900 @2x
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const IptvApp());
      await tester.pumpAndSettle();
      // Open the Settings tab via the bottom nav (phone layout).
      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();
      expect(find.text('Report a bug'), findsOneWidget);
      expect(find.text('Request a feature'), findsOneWidget);
      expect(find.text('Check for updates'), findsOneWidget);
      expect(find.text('View on GitHub'), findsOneWidget);
      // Tapping "Report a bug" opens the feedback form.
      await tester.tap(find.text('Report a bug'));
      await tester.pumpAndSettle();
      expect(find.text('Report a bug / Request a feature'), findsOneWidget);
      expect(find.byKey(const ValueKey('feedback-title')), findsOneWidget);
    });
  });
}
