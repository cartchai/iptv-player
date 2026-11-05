// Edge-case tests — extreme sizes, player across tab switches, rapid
// tab switching, and clear-channels behaviour. Run after every change.
//
// The player platform is faked here (same as state_preservation_test):
// better_player's real Android/iOS engine only exists on a device.
import 'dart:async';

import 'package:better_player_platform_interface/better_player_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptvplayer/main.dart';
import 'package:iptvplayer/state/app_state.dart';
import 'package:provider/provider.dart';

const _testStream = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';

/// Fake better_player platform: no native engine in a widget test.
class _FakeBetterPlayerPlatform extends BetterPlayerPlatform {
  @override
  Future<int?> create({BufferingConfiguration? bufferingConfiguration}) async =>
      1;

  @override
  Future<void> setDataSource(int? textureId, DataSource dataSource) async {}

  @override
  Stream<VideoEvent> videoEventsFor(int? textureId) =>
      const Stream<VideoEvent>.empty();

  @override
  Future<void> setLooping(int? textureId, bool looping) async {}

  @override
  Future<void> setVolume(int? textureId, double volume) async {}

  @override
  Future<void> play(int? textureId) async {}

  @override
  Future<void> pause(int? textureId) async {}

  @override
  Future<void> setSpeed(int? textureId, double speed) async {}

  @override
  Future<void> seekTo(int? textureId, Duration? position) async {}

  @override
  Future<Duration> getPosition(int? textureId) async => Duration.zero;

  @override
  Future<void> dispose(int? textureId) async {}

  @override
  Future<void> setMixWithOthers(int? textureId, bool mixWithOthers) async {}

  @override
  Future<void> setTrackParameters(
    int? textureId,
    int? width,
    int? height,
    int? bitrate,
  ) async {}

  @override
  Widget buildView(int? textureId) =>
      const SizedBox.expand(child: ColoredBox(color: Colors.black));
}

void _mockPlatformChannels() {
  BetterPlayerPlatform.instance = _FakeBetterPlayerPlatform();
  // wakelock_plus is used by better_player's controls.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('wakelock_plus'),
    (MethodCall call) async {
      if (call.method == 'isEnabled') return false;
      return null;
    },
  );
}

/// Logical size -> physical size at DPR 2, pump the app, settle.
Future<void> pumpAt(WidgetTester tester, Size logical) async {
  tester.view.physicalSize = Size(logical.width * 2, logical.height * 2);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const IptvApp());
  await tester.pumpAndSettle();
}

/// Settle the tree without pumpAndSettle (which never returns once the
/// player's periodic position timer is running).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump();
}

AppState _appState(WidgetTester tester) =>
    Provider.of<AppState>(tester.element(find.byType(HomeShell)), listen: false);

void main() {
  group('extreme sizes', () {
    testWidgets('very small phone 320x568: bottom nav, no overflow',
        (tester) async {
      await pumpAt(tester, const Size(320, 568));
      expect(find.byKey(const ValueKey('bottom-nav')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('very small phone 320x568 with demo channels: list renders',
        (tester) async {
      await pumpAt(tester, const Size(320, 568));
      await tester.tap(find.byKey(const ValueKey('load-demo-btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('channel-list')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'very large screen 2560x1440: side rail, list + EPG, no overflow',
        (tester) async {
      await pumpAt(tester, const Size(2560, 1440));
      expect(find.byKey(const ValueKey('side-rail')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('load-demo-btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('channel-list')), findsOneWidget);
      expect(find.byKey(const ValueKey('epg-list')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('player across tab switches', () {
    testWidgets(
        'player controller survives switching away from Live and back',
        (tester) async {
      _mockPlatformChannels();
      await pumpAt(tester, const Size(400, 900));
      final appState = _appState(tester);
      await tester.tap(find.byKey(const ValueKey('load-demo-btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('channel-3')));
      await tester.pumpAndSettle();
      appState.ensurePlayer(_testStream);
      await _settle(tester);
      final playerBefore = appState.playerController;
      expect(playerBefore, isNotNull);
      // Switch to Guide, then Settings, then back to Live.
      appState.setTab(1);
      await tester.pumpAndSettle();
      appState.setTab(4);
      await tester.pumpAndSettle();
      appState.setTab(0);
      await _settle(tester);
      expect(identical(appState.playerController, playerBefore), isTrue,
          reason: 'player controller must not be recreated on tab switch');
      expect(appState.playerUrl, _testStream);
      expect(appState.selectedChannelIndex, 3);
      expect(tester.takeException(), isNull);
      appState.disposePlayer();
      await tester.pump(const Duration(seconds: 60));
      await _settle(tester);
    });
  });

  group('tab switching and channels', () {
    testWidgets('rapid tab switching does not crash', (tester) async {
      await pumpAt(tester, const Size(400, 900));
      final appState = _appState(tester);
      await tester.tap(find.byKey(const ValueKey('load-demo-btn')));
      await tester.pumpAndSettle();
      for (var i = 0; i < 10; i++) {
        appState.setTab(i % 5);
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('clearing channels resets selection and shows empty state',
        (tester) async {
      await pumpAt(tester, const Size(400, 900));
      final appState = _appState(tester);
      await tester.tap(find.byKey(const ValueKey('load-demo-btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('channel-3')));
      await tester.pumpAndSettle();
      expect(appState.selectedChannelIndex, 3);
      expect(appState.hasPlaylist, isTrue);
      appState.clearChannels();
      await tester.pumpAndSettle();
      expect(appState.selectedChannelIndex, -1);
      expect(appState.hasPlaylist, isFalse);
      expect(find.text('No playlist yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
