// Responsive layout tests — run at every size after every change.
//
// Sizes (logical dp): phone portrait, phone landscape, Fold 7 cover,
// Fold 7 unfolded, tablet portrait/landscape, TV 16:9, Quest panel,
// small phone. For each: the right nav (bottom vs side rail) is present,
// the right content arrangement is shown, no overflow, touch targets >=48.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptvplayer/main.dart';

/// Logical size -> physical size at DPR 2, pump the app, settle.
Future<void> pumpAt(WidgetTester tester, Size logical) async {
  tester.view.physicalSize = Size(logical.width * 2, logical.height * 2);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const IptvApp());
  await tester.pumpAndSettle();
}

Future<void> loadDemo(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('load-demo-btn')));
  await tester.pumpAndSettle();
}

void main() {
  group('nav adapts to width', () {
    testWidgets('phone portrait 390x844: bottom nav, no side rail', (tester) async {
      await pumpAt(tester, const Size(390, 844));
      expect(find.byKey(const ValueKey('bottom-nav')), findsOneWidget);
      expect(find.byKey(const ValueKey('side-rail')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Fold 7 cover 400x900: bottom nav, no side rail', (tester) async {
      await pumpAt(tester, const Size(400, 900));
      expect(find.byKey(const ValueKey('bottom-nav')), findsOneWidget);
      expect(find.byKey(const ValueKey('side-rail')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('small phone 360x740: bottom nav, no overflow', (tester) async {
      await pumpAt(tester, const Size(360, 740));
      expect(find.byKey(const ValueKey('bottom-nav')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('phone landscape 844x390: wide enough for the rail', (tester) async {
      await pumpAt(tester, const Size(844, 390));
      expect(find.byKey(const ValueKey('side-rail')), findsOneWidget);
      expect(find.byKey(const ValueKey('bottom-nav')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Fold 7 unfolded 800x800: side rail, no bottom nav', (tester) async {
      await pumpAt(tester, const Size(800, 800));
      expect(find.byKey(const ValueKey('side-rail')), findsOneWidget);
      expect(find.byKey(const ValueKey('bottom-nav')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tablet portrait 800x1280: side rail', (tester) async {
      await pumpAt(tester, const Size(800, 1280));
      expect(find.byKey(const ValueKey('side-rail')), findsOneWidget);
      expect(find.byKey(const ValueKey('bottom-nav')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tablet landscape 1280x800: side rail', (tester) async {
      await pumpAt(tester, const Size(1280, 800));
      expect(find.byKey(const ValueKey('side-rail')), findsOneWidget);
      expect(find.byKey(const ValueKey('bottom-nav')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TV 16:9 1920x1080: side rail, no bottom nav', (tester) async {
      await pumpAt(tester, const Size(1920, 1080));
      expect(find.byKey(const ValueKey('side-rail')), findsOneWidget);
      expect(find.byKey(const ValueKey('bottom-nav')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Quest panel 1280x720: side rail', (tester) async {
      await pumpAt(tester, const Size(1280, 720));
      expect(find.byKey(const ValueKey('side-rail')), findsOneWidget);
      expect(find.byKey(const ValueKey('bottom-nav')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Live content arrangement', () {
    testWidgets('phone: channel list only, no EPG grid beside it', (tester) async {
      await pumpAt(tester, const Size(390, 844));
      await loadDemo(tester);
      expect(find.byKey(const ValueKey('channel-list')), findsOneWidget);
      expect(find.byKey(const ValueKey('epg-list')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Fold 7 unfolded: channel list + EPG grid side by side', (tester) async {
      await pumpAt(tester, const Size(800, 800));
      await loadDemo(tester);
      expect(find.byKey(const ValueKey('channel-list')), findsOneWidget);
      expect(find.byKey(const ValueKey('epg-list')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TV 16:9: channel list + EPG grid side by side', (tester) async {
      await pumpAt(tester, const Size(1920, 1080));
      await loadDemo(tester);
      expect(find.byKey(const ValueKey('channel-list')), findsOneWidget);
      expect(find.byKey(const ValueKey('epg-list')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('touch targets and scrolling', () {
    testWidgets('channel rows are >=48dp tall (phone)', (tester) async {
      await pumpAt(tester, const Size(390, 844));
      await loadDemo(tester);
      final size = tester.getSize(find.byKey(const ValueKey('channel-0')));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });

    testWidgets('channel list scrolls without overflow (phone)', (tester) async {
      await pumpAt(tester, const Size(390, 844));
      await loadDemo(tester);
      await tester.drag(find.byKey(const ValueKey('channel-list')), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.drag(find.byKey(const ValueKey('channel-list')), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('EPG grid scrolls without overflow (unfolded)', (tester) async {
      await pumpAt(tester, const Size(800, 800));
      await loadDemo(tester);
      await tester.drag(find.byKey(const ValueKey('epg-list')), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Settings page renders at every size without overflow', (tester) async {
      for (final size in const [
        Size(390, 844),
        Size(800, 800),
        Size(1920, 1080),
      ]) {
        await pumpAt(tester, size);
        // Go to Settings via the bottom nav (phone) or the rail (wide).
        final settings = find.text('Settings');
        await tester.tap(settings.first);
        await tester.pumpAndSettle();
        // Settings page content (its AppBar title only exists on narrow).
        expect(find.text('About'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
