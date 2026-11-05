// Fold/unfold state preservation — the seamless requirement.
//
// Resize the window (cover -> unfolded -> cover -> TV) and prove:
//   * the AppState object is never recreated,
//   * the selected channel, current tab and both scroll offsets survive,
//   * the BetterPlayerController is the SAME object (video keeps playing,
//     no restart/reload), and its URL is unchanged.
//
// The player platform is faked (better_player's real Android/iOS engine
// only exists on a device), and the wakelock channel is mocked. The fake
// returns a texture id and no-ops every call, so the controller can be
// created and its identity tracked without real playback.
//
// NOTE: once the controller exists, better_player runs a 300ms periodic
// position timer, so pumpAndSettle() never settles. After ensurePlayer we
// use explicit pump() frames (_settle) instead of pumpAndSettle().
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

/// Settle the tree without pumpAndSettle (which never returns once the
/// player's periodic position timer is running).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump();
}

Future<void> _resize(WidgetTester tester, Size logical) async {
  tester.view.physicalSize = Size(logical.width * 2, logical.height * 2);
  tester.view.devicePixelRatio = 2.0;
  await _settle(tester);
}

void main() {
  testWidgets('fold/unfold keeps state and the player controller',
      (tester) async {
    _mockPlatformChannels();
    tester.view.physicalSize = const Size(800, 1800); // 400x900 @2x
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const IptvApp());
    await tester.pumpAndSettle();

    final appState = Provider.of<AppState>(
      tester.element(find.byType(HomeShell)),
      listen: false,
    );

    // Set up state: demo channels, select channel 3, Guide tab, scroll EPG.
    await tester.tap(find.byKey(const ValueKey('load-demo-btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('channel-3')));
    await tester.pumpAndSettle();
    appState.setTab(1); // Guide — EPG list visible.
    await tester.pumpAndSettle();
    final epgTarget = appState.epgScrollController.hasClients
        ? appState.epgScrollController.position.maxScrollExtent.clamp(0, 120).toDouble()
        : 0.0;
    if (epgTarget > 0) {
      appState.epgScrollController.jumpTo(epgTarget);
      await tester.pumpAndSettle();
    }
    // Back to Live, scroll the channel list.
    appState.setTab(0);
    await tester.pumpAndSettle();
    final chTarget = appState.channelScrollController.hasClients
        ? appState.channelScrollController.position.maxScrollExtent.clamp(0, 200).toDouble()
        : 0.0;
    if (chTarget > 0) {
      appState.channelScrollController.jumpTo(chTarget);
      await tester.pumpAndSettle();
    }
    // Create the player (real BetterPlayerController, test HLS URL).
    appState.ensurePlayer(_testStream);
    await _settle(tester);

    final stateBefore = appState;
    final playerBefore = appState.playerController;
    final selectedBefore = appState.selectedChannelIndex;
    final tabBefore = appState.currentTab;
    final chOffsetBefore = appState.channelScrollOffset;
    final epgOffsetBefore = appState.epgScrollOffset;
    expect(playerBefore, isNotNull);
    expect(selectedBefore, 3);
    expect(tabBefore, 0);

    // Fold 7 unfolded (800x800) — wide layout.
    await _resize(tester, const Size(800, 800));
    expect(identical(appState, stateBefore), isTrue);
    expect(identical(appState.playerController, playerBefore), isTrue,
        reason: 'player controller must not be recreated on unfold');
    expect(appState.playerUrl, _testStream);
    expect(appState.selectedChannelIndex, selectedBefore);
    expect(appState.currentTab, tabBefore);
    expect(appState.channelScrollOffset, chOffsetBefore);
    expect(appState.epgScrollOffset, epgOffsetBefore);
    expect(find.byKey(const ValueKey('side-rail')), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Fold back to cover (400x900) — narrow layout.
    await _resize(tester, const Size(400, 900));
    expect(identical(appState.playerController, playerBefore), isTrue,
        reason: 'player controller must not be recreated on fold');
    expect(appState.selectedChannelIndex, selectedBefore);
    expect(appState.currentTab, tabBefore);
    expect(appState.channelScrollOffset, chOffsetBefore);
    expect(appState.epgScrollOffset, epgOffsetBefore);
    expect(find.byKey(const ValueKey('bottom-nav')), findsOneWidget);
    expect(tester.takeException(), isNull);

    // TV wide (1920x1080).
    await _resize(tester, const Size(1920, 1080));
    expect(identical(appState.playerController, playerBefore), isTrue);
    expect(appState.selectedChannelIndex, selectedBefore);
    expect(appState.currentTab, tabBefore);
    expect(appState.channelScrollOffset, chOffsetBefore);
    expect(appState.epgScrollOffset, epgOffsetBefore);
    expect(find.byKey(const ValueKey('side-rail')), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Tear down the player so its 300ms position timer is cancelled before
    // the tree is disposed (otherwise the test framework flags a pending
    // timer). Then advance the fake clock past better_player's internal
    // HttpClient idle timeout (its HLS manifest fetch keeps a pooled
    // connection alive ~15s); without this, the framework still flags a
    // pending one-shot timer even though the player itself is disposed.
    appState.disposePlayer();
    await tester.pump(const Duration(seconds: 60));
    await _settle(tester);
  });

  testWidgets('ensurePlayer does not recreate the controller', (tester) async {
    _mockPlatformChannels();
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const IptvApp());
    await tester.pumpAndSettle();
    final appState = Provider.of<AppState>(
      tester.element(find.byType(HomeShell)),
      listen: false,
    );
    appState.ensurePlayer(_testStream);
    await _settle(tester);
    final first = appState.playerController;
    expect(first, isNotNull);
    appState.ensurePlayer('https://example.com/other.m3u8');
    await _settle(tester);
    expect(identical(appState.playerController, first), isTrue);
    expect(appState.playerUrl, _testStream);
    expect(tester.takeException(), isNull);

    // Cancel the player's position timer before the tree is disposed, and
    // advance the fake clock past better_player's internal HttpClient idle
    // timeout (see above).
    appState.disposePlayer();
    await tester.pump(const Duration(seconds: 60));
    await _settle(tester);
  });
}
