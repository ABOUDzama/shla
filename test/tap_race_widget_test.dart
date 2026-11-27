import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/games/offline/tap_race_game.dart';
import 'package:shella/services/results_service.dart';
import 'package:shella/widgets/victory_friends.dart';
import 'package:shella/services/audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => AudioService.mutedForTests = true);
  tearDown(() => AudioService.mutedForTests = false);
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    for (final name in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black']) {
      final bytes = await File('assets/fonts/Cairo-$name.ttf').readAsBytes();
      final loader = FontLoader('Cairo')..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
    final emojiBytes = await File('test/fonts_NotoColorEmoji.ttf').readAsBytes();
    final l = FontLoader('Noto Color Emoji')..addFont(Future.value(ByteData.sublistView(emojiBytes)));
    await l.load();
    final mi = await File('${Platform.environment['HOME']}/sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytes();
    final il = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(mi)));
    await il.load();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(textDirection: TextDirection.rtl, child: const TapRaceGame()),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await tester.pump();
    await tester.ensureVisible(find.text('ابدأ اللعبة 🚀'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('ابدأ اللعبة 🚀'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 600)));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  }

  TapRaceMatch m(WidgetTester t) =>
      (t.state(find.byType(TapRaceGame)) as dynamic).debugMatch as TapRaceMatch;

  testWidgets('3 humans + bots yes: lanes tap only own seat, bot seats fill', (tester) async {
    await open(tester);
    await tester.tap(find.text('3 لاعبين'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('اه 🤖'));
    for (var i = 0; i < 30 && find.byKey(const ValueKey('clock')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byKey(const ValueKey('clock')), findsOneWidget);
    final bots = (tester.state(find.byType(TapRaceGame)) as dynamic).debugBots as Set<int>;
    expect(bots, {3});
    await tester.tap(find.byKey(const ValueKey('lane_1')), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 50));
    expect(m(tester).taps[1], greaterThan(0));
    expect(m(tester).taps[0], 0);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(m(tester).taps[3], greaterThan(0), reason: 'bot taps on its own');
    await settle(tester);
  });

  testWidgets('1 human + no bots is practice: no bot seats', (tester) async {
    await open(tester);
    await tester.tap(find.text('لاعب واحد'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('لا'));
    for (var i = 0; i < 30 && find.byKey(const ValueKey('clock')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    final bots = (tester.state(find.byType(TapRaceGame)) as dynamic).debugBots as Set<int>;
    expect(bots, isEmpty);
    await settle(tester);
  });


  testWidgets('2p ported: countdown ignores taps, exact sprint counts, rounds, match win, replay',
      (tester) async {
    await open(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('لا'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    // countdown phase: taps must not count
    await tester.tap(find.byKey(const ValueKey('lane_0')), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(m(tester).taps[0], 0);
    // sprint: exact counts shown on the lane
    for (var i = 0; i < 30 && find.byKey(const ValueKey('clock')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const ValueKey('lane_0')));
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(m(tester).taps[0], 4);
    expect(find.text('4'), findsWidgets);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('lane_1')));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(m(tester).taps[1], 3);
    // player 1 wins three rounds -> match over -> replay back to the picker
    for (var round = 1; round <= 3; round++) {
      for (var i = 0;
          i < 40 && find.text('ماتش جديد').evaluate().isEmpty && find.text('الجولة الجاية').evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      if (find.text('ماتش جديد').evaluate().isNotEmpty) break;
      await tester.tap(find.text('الجولة الجاية'));
      await tester.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < 30 && find.byKey(const ValueKey('clock')).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      for (var i = 0; i < 8; i++) {
        await tester.tap(find.byKey(const ValueKey('lane_0')));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    expect(find.text('ماتش جديد'), findsOneWidget);
    expect(find.byType(VictoryFriends), findsOneWidget);
    await tester.tap(find.text('ماتش جديد'));
    await tester.pump();
    expect(find.text('كام لاعب؟'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('4p ported: four lanes render and count per lane', (tester) async {
    await open(tester);
    await tester.tap(find.text('4 لاعبين'));
    for (var i = 0; i < 30 && find.byKey(const ValueKey('clock')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byKey(const ValueKey('lane_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('lane_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('lane_2')), findsOneWidget);
    expect(find.byKey(const ValueKey('lane_3')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lane_3')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(m(tester).taps[3], 1);
    expect(m(tester).taps[0], 0);
    await settle(tester);
  });


  testWidgets('3p ported: three lanes render without bots', (tester) async {
    await open(tester);
    await tester.tap(find.text('3 لاعبين'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(m(tester).players, 3);
    expect(find.byKey(const ValueKey('lane_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('lane_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('lane_2')), findsOneWidget);
    await settle(tester);
  });
}
