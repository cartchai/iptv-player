// Smoke test: the app launches, shows the empty state, and the
// "Add playlist" placeholder responds. Run repeatedly after every change.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptvplayer/main.dart';

void main() {
  testWidgets('App launches with the empty state', (tester) async {
    tester.view.physicalSize = const Size(800, 1800); // 400x900 @2x
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const IptvApp());
    await tester.pumpAndSettle();

    expect(find.text('IPTV Player'), findsWidgets);
    expect(find.text('No playlist yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('bottom-nav')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-playlist-btn')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add playlist shows the coming-next note', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const IptvApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-playlist-btn')));
    await tester.pumpAndSettle();
    expect(find.textContaining('coming next'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Demo channels load and a channel can be selected', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const IptvApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('load-demo-btn')));
    await tester.pumpAndSettle();
    expect(find.text('No playlist yet'), findsNothing);
    expect(find.byKey(const ValueKey('channel-list')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('channel-2')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
