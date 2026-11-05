// IPTV Player — scaffold shell (Android first, phone-first).
//
// Working title "IPTV Player", package com.matt.iptvplayer. Free app, no
// paywall. No TiviMate name/logo anywhere.
//
// Architecture (this is what makes fold/unfold seamless):
//   * AppState (a ChangeNotifier, provided ABOVE the shell) owns the player
//     controller, the selected channel, the current tab and both scroll
//     controllers. A resize rebuild never recreates it.
//   * ResponsiveLayout picks narrow / tablet / wide from the *available*
//     width, and every branch renders the SAME tab-page widgets — only the
//     arrangement (bottom nav vs side rail, single column vs two-pane)
//     changes. No restart, no reload, no state reset on fold/unfold.
//
// No IPTV import / EPG data / real playback yet — that's the next step.
// The shell renders labelled demo channels so the list, guide and selection
// can be exercised; the player area is a placeholder until Live TV lands.
import 'package:better_player/better_player.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'responsive.dart';
import 'state/app_state.dart';
import 'theme.dart';

void main() {
  runApp(const IptvApp());
}

class IptvApp extends StatelessWidget {
  const IptvApp({super.key});

  @override
  Widget build(BuildContext context) {
    // The provider lives here (not in main()) so the app is self-contained:
    // pumping IptvApp in a test gets the same AppState wiring as the real
    // app. ChangeNotifierProvider creates AppState once per element lifetime
    // and reuses it across rebuilds, so a resize never recreates it.
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'IPTV Player',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const HomeShell(),
      ),
    );
  }
}

/// The shell: same tab pages everywhere, navigation chrome adapts.
/// Narrow (phone / Fold 7 cover): AppBar + bottom nav.
/// Tablet (Fold 7 unfolded) / wide (TV, Quest): side rail, no bottom nav.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  static const _tabs = <({IconData icon, String label})>[
    (icon: Icons.live_tv, label: 'Live'),
    (icon: Icons.table_chart, label: 'Guide'),
    (icon: Icons.movie, label: 'Movies'),
    (icon: Icons.tv, label: 'Series'),
    (icon: Icons.settings, label: 'Settings'),
  ];

  Widget _tabPage(int tab) {
    return switch (tab) {
      0 => const LivePage(),
      1 => const GuidePage(),
      2 => const MoviesPage(),
      3 => const SeriesPage(),
      _ => const SettingsPage(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return ResponsiveLayout(
      narrow: (_) => Scaffold(
        appBar: AppBar(
          title: const Text('IPTV Player'),
          actions: [
            IconButton(
              key: const ValueKey('appbar-settings'),
              icon: const Icon(Icons.settings),
              tooltip: 'Settings',
              onPressed: () => appState.setTab(4),
            ),
          ],
        ),
        body: _tabPage(appState.currentTab),
        bottomNavigationBar: BottomNavigationBar(
          key: const ValueKey('bottom-nav'),
          currentIndex: appState.currentTab,
          onTap: appState.setTab,
          items: [
            for (final t in _tabs)
              BottomNavigationBarItem(icon: Icon(t.icon), label: t.label),
          ],
        ),
      ),
      tablet: (_) => Scaffold(
        body: Row(
          children: [
            NavigationRail(
              key: const ValueKey('side-rail'),
              selectedIndex: appState.currentTab,
              onDestinationSelected: appState.setTab,
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Icon(Icons.live_tv, color: AppTheme.accent, size: 30),
              ),
              destinations: [
                for (final t in _tabs)
                  NavigationRailDestination(icon: Icon(t.icon), label: Text(t.label)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _tabPage(appState.currentTab)),
          ],
        ),
      ),
      wide: (_) => Scaffold(
        body: Row(
          children: [
            NavigationRail(
              key: const ValueKey('side-rail'),
              selectedIndex: appState.currentTab,
              onDestinationSelected: appState.setTab,
              labelType: NavigationRailLabelType.all,
              minWidth: 88,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Icon(Icons.live_tv, color: AppTheme.accent, size: 30),
              ),
              destinations: [
                for (final t in _tabs)
                  NavigationRailDestination(icon: Icon(t.icon), label: Text(t.label)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _tabPage(appState.currentTab)),
          ],
        ),
      ),
    );
  }
}

/// Live tab: player on top, then channel list — plus the EPG grid beside
/// the list once there is room (>=600dp inside the page).
class LivePage extends StatelessWidget {
  const LivePage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    if (!appState.hasPlaylist) return const EmptyPlaylistView();
    return Column(
      children: [
        const RepaintBoundary(child: PlayerArea()),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= AppBreakpoints.phoneMaxWidth) {
                return Row(
                  children: const [
                    SizedBox(width: 300, child: ChannelListView()),
                    VerticalDivider(width: 1),
                    Expanded(child: EpgGridView()),
                  ],
                );
              }
              return const ChannelListView();
            },
          ),
        ),
      ],
    );
  }
}

/// 16:9 player area. Real playback lands with Live TV; until then it shows
/// the selected channel name (or a prompt) — never a fake video.
class PlayerArea extends StatelessWidget {
  const PlayerArea({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final controller = appState.playerController;
    if (controller != null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: BetterPlayer(controller: controller),
      );
    }
    final selected = appState.selectedChannelIndex >= 0
        ? appState.channels[appState.selectedChannelIndex].name
        : null;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_circle_outline, size: 56, color: AppTheme.textSecondary),
              const SizedBox(height: 8),
              Text(
                selected ?? 'Select a channel to play',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
              ),
              const Text(
                'Playback comes with Live TV — this is the shell.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Channel list. Lazy (builder), fixed row height, >=48dp targets.
/// Uses the AppState-owned scroll controller, so the offset survives a
/// fold/unfold layout switch.
class ChannelListView extends StatelessWidget {
  const ChannelListView({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final channels = appState.channels;
    return ListView.builder(
      key: const ValueKey('channel-list'),
      controller: appState.channelScrollController,
      itemCount: channels.length,
      itemExtent: 64,
      itemBuilder: (context, index) {
        final channel = channels[index];
        final selected = index == appState.selectedChannelIndex;
        return _ChannelRow(
          key: ValueKey('channel-$index'),
          channel: channel,
          index: index,
          selected: selected,
          onTap: () => appState.selectChannel(index),
        );
      },
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    super.key,
    required this.channel,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final DemoChannel channel;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.accent.withValues(alpha: 0.16) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.surfaceVariant,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${channel.group} · DEMO',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.play_arrow, color: AppTheme.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// EPG grid placeholder: time header + virtualised rows of programme blocks.
/// Vertical scrolling uses the AppState-owned controller (offset survives a
/// fold/unfold). Horizontal scrolling is per-row for now; syncing the rows
/// to one shared horizontal offset lands with the real guide.
class EpgGridView extends StatelessWidget {
  const EpgGridView({super.key});

  static const _hours = ['Now', '18:00', '19:00', '20:00', '21:00', '22:00', '23:00'];

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final channels = appState.channels;
    return RepaintBoundary(
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const SizedBox(width: 112),
                  for (final h in _hours)
                    SizedBox(
                      width: 140,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8, top: 12),
                        child: Text(h, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              key: const ValueKey('epg-list'),
              controller: appState.epgScrollController,
              itemCount: channels.length,
              itemExtent: 64,
              itemBuilder: (context, index) {
                final channel = channels[index];
                return SizedBox(
                  height: 64,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 112,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            channel.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (int s = 0; s < 6; s++)
                                Container(
                                  width: 140,
                                  height: 48,
                                  margin: const EdgeInsets.only(right: 4, top: 8, bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceVariant,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${channel.group} show ${s + 1}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Guide tab: the EPG grid full-width.
class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    if (!appState.hasPlaylist) return const EmptyPlaylistView();
    return const Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Guide', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
        ),
        Expanded(child: EpgGridView()),
      ],
    );
  }
}

class MoviesPage extends StatelessWidget {
  const MoviesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ComingSoon(icon: Icons.movie, title: 'Movies', subtitle: 'Movies & VOD come with the Xtream catalogue — next step.');
  }
}

class SeriesPage extends StatelessWidget {
  const SeriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ComingSoon(icon: Icons.tv, title: 'Series', subtitle: 'Series with seasons & episodes come with the Xtream catalogue — next step.');
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// Empty state: no playlist configured yet.
class EmptyPlaylistView extends StatelessWidget {
  const EmptyPlaylistView({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.live_tv, size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            const Text('No playlist yet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'Add an Xtream Codes login or an M3U playlist to start watching.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              key: const ValueKey('add-playlist-btn'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Playlist import is coming next — this is the scaffold.')),
                );
              },
              child: const Text('Add playlist'),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const ValueKey('load-demo-btn'),
              onPressed: appState.loadDemoChannels,
              child: const Text('Load demo channels (shell test)'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings tab (placeholder rows until settings land).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: const [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('Playlists', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
        ),
        ListTile(
          leading: Icon(Icons.playlist_add),
          title: Text('Add playlist'),
          subtitle: Text('Xtream Codes login or M3U URL — coming next'),
        ),
        Divider(),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('Appearance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
        ),
        ListTile(
          leading: Icon(Icons.dark_mode),
          title: Text('Theme'),
          subtitle: Text('Dark'),
        ),
        Divider(),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('About', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
        ),
        ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('IPTV Player'),
          subtitle: Text('Version 0.1.0 (scaffold) · com.matt.iptvplayer'),
        ),
      ],
    );
  }
}
