import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/games/offline/chicken_run_game.dart';
import 'package:shella/games/offline/chicken_run_logic.dart';
import 'package:shella/services/results_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
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
      home: Directionality(textDirection: TextDirection.rtl, child: ChickenRunGame(randomSeed: 3)),
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

  ChickenRunMatch m(WidgetTester t) =>
      (t.state(find.byType(ChickenRunGame)) as dynamic).debugMatch as ChickenRunMatch;

  Future<void> tapIfHoleAhead(WidgetTester tester, int seat) async {
    final match = m(tester);
    if (!match.alive[seat] || match.flightLeft[seat] > 0) return;
    final cx = match.scroll + ChickenRunMatch.chickenX;
    final h = match.nextHole(match.surface[seat], cx);
    if (h == null) return;
    final dist = h.start - cx;
    if (dist > 0 && dist < match.speed * ChickenRunMatch.flipTime + 0.12) {
      await tester.tap(find.byKey(ValueKey('pad_$seat')));
    }
  }

  testWidgets('4 players: holes scroll, pad flips only its own chicken mid-air', (tester) async {
    await open(tester);
    await tester.tap(find.text('4 لاعبين'));
    await tester.pump(const Duration(milliseconds: 100));
    final match = m(tester);
    expect(match.seats, 4);
    expect(match.botSeats, isEmpty);
    for (final s in [0, 1, 2, 3]) {
      expect(find.byKey(ValueKey('pad_$s')), findsOneWidget);
    }
    // keep seat 3 (index 2) safe and play until a hole is on screen
    for (var i = 0; i < 200 && !(match.holes.any((h) => h.start - match.scroll < 0.62 && h.start - match.scroll > 0.45)); i++) {
      await tester.pump(const Duration(milliseconds: 33));
      for (final s in [0, 1, 2, 3]) { await tapIfHoleAhead(tester, s); }
    }
    expect(match.alive.where((a) => a).length, 4);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/chicken_run_holes.png'));
    final before = match.surface[1];
    await tester.tap(find.byKey(const ValueKey('pad_1')));
    await tester.pump(const Duration(milliseconds: 130));
    expect(match.flightLeft[1], greaterThan(0), reason: 'seat 2 mid-flight');
    expect(match.flightLeft[0], 0, reason: 'other pads untouched');
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/chicken_run_flip_midair.png'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(match.surface[1], isNot(before));
    await settle(tester);
  });

  testWidgets('3 players: idle chicken falls (elimination), then winner and result', (tester) async {
    await open(tester);
    await tester.tap(find.text('3 لاعبين'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 100));
    final match = m(tester);
    // seat 0 (bottom-left) never taps; seats 1 and 2 survive by tapping pads
    var shotElim = false;
    for (var i = 0; i < 900 && !match.over; i++) {
      await tester.pump(const Duration(milliseconds: 33));
      await tapIfHoleAhead(tester, 1);
      if (!shotElim && !match.alive[0]) {
        await tester.pump(const Duration(milliseconds: 33));
        await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/chicken_run_elimination.png'));
        shotElim = true;
      }
      if (shotElim) {
        // seat 2 stops tapping so exactly one chicken remains
      } else {
        await tapIfHoleAhead(tester, 2);
      }
    }
    expect(shotElim, true, reason: 'idle seat fell first');
    expect(match.over, true);
    expect(match.winner, 1);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('لاعب 2'), findsWidgets);
    final recorded = await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 150));
      return ResultsService.instance.load();
    });
    expect(recorded!.length, 1);
    expect(recorded.first.game, 'جري الفراخ');
    expect(recorded.first.winner, 'لاعب 2');
    // persistence: a fresh read from storage still has the same single row
    final again = await tester.runAsync(() => ResultsService.instance.load());
    expect(again!.map((r) => r.winner), ['لاعب 2']);
    await tester.pump(const Duration(seconds: 2));
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/chicken_run_win.png'));
    await settle(tester);
  });

  testWidgets('draw: two chickens falling in the same tick end in a draw', (tester) async {
    await open(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 100));
    final match = m(tester);
    match.holes.insert(0, Hole(0, match.scroll + 0.2, match.scroll + 0.6));
    for (var i = 0; i < 100 && !match.over; i++) {
      await tester.pump(const Duration(milliseconds: 33));
    }
    expect(match.over, true);
    expect(match.winner, isNull);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('تعادل'), findsOneWidget);
    final rec = await tester.runAsync(() => ResultsService.instance.load());
    expect(rec, isEmpty, reason: 'a draw records no winner');
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/chicken_run_draw.png'));
    await settle(tester);
  });

  testWidgets('bots rule: 2 players "لا" has no bots; "اه" fills to 4', (tester) async {
    await open(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(m(tester).seats, 2);
    expect(m(tester).botSeats, isEmpty);
    await tester.pump(const Duration(seconds: 12));
    await settle(tester);
  });

  testWidgets('bots "اه": humans 2 + 2 bots', (tester) async {
    await open(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('اه 🤖'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(m(tester).seats, 4);
    expect(m(tester).botSeats, {2, 3});
    await tester.pump(const Duration(seconds: 12));
    await settle(tester);
  });

  testWidgets('practice: 1 player "لا" runs alone, ends on falling, no result', (tester) async {
    await open(tester);
    await tester.tap(find.text('لاعب واحد'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(m(tester).seats, 1);
    // never press: the chicken eventually stands on a floor hole
    for (var i = 0; i < 400 && find.textContaining('وقعت بعد').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('وقعت بعد'), findsOneWidget);
    final rec = await tester.runAsync(() => ResultsService.instance.load());
    expect(rec, isEmpty, reason: 'practice records no winner');
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/chicken_run_over.png'));
    await settle(tester);
  });
}
