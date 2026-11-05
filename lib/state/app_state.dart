// App state — owned by a provider *above* the responsive shell.
//
// This is the whole point of the Fold 7 seamless requirement: the player
// controller, the selected channel, the current tab and the scroll offsets
// live here, NOT in a layout widget. When the phone folds/unfolds, the
// shell rebuilds (narrow <-> wide) but this object is never recreated, so
// the video keeps playing, the selection stays, and the EPG scroll position
// is preserved. No restart, no reload, no state reset.
//
// Scroll offsets are saved in plain fields via listeners, so they stay
// readable even while a controller is briefly detached during a layout
// switch (ScrollController.offset throws when it has no clients).
import 'package:better_player/better_player.dart';
import 'package:flutter/widgets.dart';

/// A demo channel — placeholder data so the shell (list, EPG, selection)
/// can be exercised before any real playlist is imported. Clearly labelled
/// DEMO in the UI; real import replaces this.
class DemoChannel {
  const DemoChannel({required this.id, required this.name, required this.group});
  final int id;
  final String name;
  final String group;
}

class AppState extends ChangeNotifier {
  AppState() {
    _channelScrollController.addListener(() {
      _channelOffset = _channelScrollController.hasClients
          ? _channelScrollController.offset
          : _channelOffset;
    });
    _epgScrollController.addListener(() {
      _epgOffset = _epgScrollController.hasClients
          ? _epgScrollController.offset
          : _epgOffset;
    });
  }

  // --- Tabs: 0 Live, 1 Guide, 2 Movies, 3 Series, 4 Settings. ---
  int currentTab = 0;
  void setTab(int index) {
    if (index != currentTab) {
      currentTab = index;
      notifyListeners();
    }
  }

  // --- Channels (demo data until import lands). ---
  static const List<DemoChannel> demoChannels = [
    DemoChannel(id: 1, name: 'Demo News 24', group: 'News'),
    DemoChannel(id: 2, name: 'Demo Sports 1', group: 'Sports'),
    DemoChannel(id: 3, name: 'Demo Sports 2', group: 'Sports'),
    DemoChannel(id: 4, name: 'Demo Movies HD', group: 'Movies'),
    DemoChannel(id: 5, name: 'Demo Movies 2', group: 'Movies'),
    DemoChannel(id: 6, name: 'Demo Kids', group: 'Kids'),
    DemoChannel(id: 7, name: 'Demo Kids 2', group: 'Kids'),
    DemoChannel(id: 8, name: 'Demo Music', group: 'Music'),
    DemoChannel(id: 9, name: 'Demo Docs', group: 'Documentary'),
    DemoChannel(id: 10, name: 'Demo Comedy', group: 'Entertainment'),
    DemoChannel(id: 11, name: 'Demo Drama', group: 'Entertainment'),
    DemoChannel(id: 12, name: 'Demo Weather', group: 'News'),
  ];

  List<DemoChannel> _channels = const [];
  List<DemoChannel> get channels => _channels;
  bool get hasPlaylist => _channels.isNotEmpty;

  /// Dev/test aid: load the labelled demo channels so the shell can be
  /// exercised. Real playlist import (Xtream/M3U) replaces this.
  void loadDemoChannels() {
    _channels = demoChannels;
    notifyListeners();
  }

  void clearChannels() {
    _channels = const [];
    selectedChannelIndex = -1;
    notifyListeners();
  }

  // --- Selection. ---
  int selectedChannelIndex = -1;
  void selectChannel(int index) {
    if (index != selectedChannelIndex) {
      selectedChannelIndex = index;
      notifyListeners();
    }
  }

  // --- Scroll state (owned here, shared by every layout branch). ---
  final ScrollController _channelScrollController = ScrollController();
  final ScrollController _epgScrollController = ScrollController();
  ScrollController get channelScrollController => _channelScrollController;
  ScrollController get epgScrollController => _epgScrollController;

  double _channelOffset = 0;
  double _epgOffset = 0;
  double get channelScrollOffset => _channelOffset;
  double get epgScrollOffset => _epgOffset;

  // --- Player. Created ONCE, lazily, and never recreated by a layout
  // rebuild. A later call with the same URL is a no-op; switching streams
  // is done via setupDataSource on the same controller (next step).
  BetterPlayerController? _playerController;
  BetterPlayerController? get playerController => _playerController;
  bool get hasPlayer => _playerController != null;
  String? _playerUrl;
  String? get playerUrl => _playerUrl;

  void ensurePlayer(String url) {
    if (_playerController != null) return; // already exists — keep it.
    _playerUrl = url;
    // better_player 1.33 renamed the config/data-source types:
    // PlayerConfiguration / PlayerDataSource / DataSourceType.
    _playerController = BetterPlayerController(
      const PlayerConfiguration(
        autoPlay: true,
        aspectRatio: 16 / 9,
        fit: BoxFit.contain,
        allowedScreenSleep: false,
        // The controller lives in AppState (above the layout), so it must
        // NOT auto-dispose when the BetterPlayer widget is rebuilt or
        // temporarily removed (tab switch / fold-unfold). AppState.dispose()
        // owns its lifetime.
        autoDispose: false,
        handleLifecycle: true,
        controlsConfiguration: PlayerControlsConfiguration(
          showControls: true,
        ),
      ),
      betterPlayerDataSource: PlayerDataSource(
        DataSourceType.network,
        url,
      ),
    );
    notifyListeners();
  }

  void disposePlayer() {
    // autoDispose is false (the controller must survive tab switches and
    // fold/unfold), so a plain dispose() is a no-op — force it here, where
    // AppState owns the lifetime.
    _playerController?.dispose(forceDispose: true);
    _playerController = null;
    _playerUrl = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _playerController?.dispose(forceDispose: true);
    _channelScrollController.dispose();
    _epgScrollController.dispose();
    super.dispose();
  }
}
