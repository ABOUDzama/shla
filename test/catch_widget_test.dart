import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/games/offline/catch_game.dart';
import 'package:shella/services/results_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
      home: Directionality(textDirection: TextDirection.rtl, child: CatchGame(randomSeed: 3)),
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

  CatchMatch m(WidgetTester t) =>
      (t.state(find.byType(CatchGame)) as dynamic).debugMatch as CatchMatch;

  void spin(WidgetTester t, double v) => (t.state(find.byType(CatchGame)) as dynamic).debugSpin = v;

  testWidgets('4 players: pad in the zone scores, wrong pad is locked out', (tester) async {
    await open(tester);
    await tester.tap(find.text('4 لاعبين'));
    await tester.pump(const Duration(milliseconds: 50));
    final match = m(tester);
    expect(match.playerCount, 4);
    spin(tester, 0.625); // 225 degrees = bottom-left quadrant = seat 0's corner
    await tester.tap(find.byKey(const ValueKey('pad_0')));
    await tester.tap(find.byKey(const ValueKey('pad_1')));
    final st = tester.state(find.byType(CatchGame)) as dynamic;
    expect([st.debugScore(0), st.debugScore(1)], [1, 0]);
    spin(tester, 0.125); // 45 degrees = top-right quadrant = seat 1's corner
    await tester.tap(find.byKey(const ValueKey('pad_1')));
    expect(st.debugScore(1), 0, reason: 'seat 1 tapped wrong earlier this lap: locked out');
    spin(tester, 0.875); // 315 = top-left = seat 3 corner
    await tester.tap(find.byKey(const ValueKey('pad_3')));
    expect(st.debugScore(3), 1);
    spin(tester, 0.375); // 135 = bottom-right = seat 2: only seat 2 may score here
    await tester.tap(find.byKey(const ValueKey('pad_2')));
    expect(st.debugScore(2), 1);
    expect(find.byType(CatchGame), findsOneWidget);
    spin(tester, 0.625);
    await tester.pump(const Duration(milliseconds: 20));
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/catch_play.png'));
    await settle(tester);
  });

  testWidgets('bots: "لا" adds none, "اه" fills to 4 and they score on their own', (tester) async {
    await open(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 50));
    expect((tester.state(find.byType(CatchGame)) as dynamic).debugBots, isEmpty);
    await settle(tester);
    await open(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('اه 🤖'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(m(tester).playerCount, 4);
    final st = tester.state(find.byType(CatchGame)) as dynamic;
    expect(st.debugBots, {2, 3});
    for (var i = 0; i < 60 && m(tester).matchWinner == null; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(st.debugScore(2) + st.debugScore(3), greaterThan(0));
    await settle(tester);
  });

  testWidgets('first to 5 wins, winner screen crowns them and result is recorded', (tester) async {
    await open(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 50));
    for (var lap = 0; lap < 5; lap++) {
      spin(tester, 0.625); // seat 0's bottom-left quadrant
      await tester.tap(find.byKey(const ValueKey('pad_0')));
      spin(tester, 0.99);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 500));
    }
    final st2 = tester.state(find.byType(CatchGame)) as dynamic;
    expect(st2.debugScore(0), 5);
    expect(st2.debugWinnerSeat, 0);
    await tester.pump(const Duration(milliseconds: 600));
    final rec = await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 150));
      return ResultsService.instance.load();
    });
    expect(rec!.length, 1);
    expect(rec.first.game, 'اقطفها');
    expect(rec.first.winner, 'لاعب 1');
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('crown_0')), findsOneWidget);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/catch_win.png'));
    await settle(tester);
  });

  testWidgets('practice: lone seat, no winner recorded', (tester) async {
    await open(tester);
    await tester.tap(find.text('لاعب واحد'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 50));
    for (var lap = 0; lap < 5; lap++) {
      spin(tester, 0.625);
      await tester.tap(find.byKey(const ValueKey('pad_0')));
      spin(tester, 0.99);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('خلصت ٥ نقط'), findsOneWidget);
    final rec = await tester.runAsync(() => ResultsService.instance.load());
    expect(rec, isEmpty);
    await settle(tester);
  });
}
