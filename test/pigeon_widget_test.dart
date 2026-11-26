import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/games/offline/pigeon_game.dart';
import 'package:shella/services/audio_service.dart';
import 'package:shella/games/offline/pigeon_logic.dart';
import 'package:shella/services/results_service.dart';

void main() {
  setUp(() => AudioService.mutedForTests = true);
  tearDown(() => AudioService.mutedForTests = false);
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
      home: Directionality(textDirection: TextDirection.rtl, child: PigeonGame(randomSeed: 3)),
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

  PigeonMatch m(WidgetTester t) =>
      (t.state(find.byType(PigeonGame)) as dynamic).debugMatch as PigeonMatch;

  testWidgets('4 players: each pad fires only its own crumb and uses a shot', (tester) async {
    await open(tester);
    await tester.tap(find.text('4 لاعبين'));
    await tester.pump(const Duration(milliseconds: 100));
    final match = m(tester);
    expect(match.seats, 4);
    expect(match.botSeats, isEmpty);
    await tester.tap(find.byKey(const ValueKey('pad_1')));
    await tester.pump(const Duration(milliseconds: 120));
    expect(match.left, [8, 7, 8, 8]);
    expect(match.crumbs.length, 1);
    expect(match.crumbs.first.seat, 1);
    await tester.tap(find.byKey(const ValueKey('pad_1')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(match.left[1], 7, reason: 'cooldown blocks spam');
    await tester.tap(find.byKey(const ValueKey('pad_3')));
    await tester.tap(find.byKey(const ValueKey('pad_0')));
    await tester.pump(const Duration(milliseconds: 250));
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/pigeon_play.png'));
    await settle(tester);
  });

  testWidgets('bots: "لا" adds none, "اه" fills to 4', (tester) async {
    await open(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(m(tester).seats, 2);
    expect(m(tester).botSeats, isEmpty);
    await settle(tester);
    await open(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('اه 🤖'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(m(tester).seats, 4);
    expect(m(tester).botSeats, {2, 3});
    await settle(tester);
  });

  testWidgets('feeding: aimed taps score; winner screen and result recorded', (tester) async {
    await open(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 100));
    final match = m(tester);
    var shotMid = false;
    // Seat 0 taps only when its swinging aim lines up with the pigeon (real
    // pad taps). Seat 1 only taps when clearly off target, so seat 0 leads.
    for (var i = 0; i < 4000 && !match.over; i++) {
      await tester.pump(const Duration(milliseconds: 33));
      if (match.left[0] > 0 && match.cooldown[0] <= 0) {
        final l = PigeonMatch.launchers[0];
        final p = match.pigeon;
        final want = atan2(p.y - l[1], p.x - l[0]);
        var d = match.aim(0) - want;
        while (d > pi) { d -= 2 * pi; }
        while (d < -pi) { d += 2 * pi; }
        if (d.abs() < 0.04) await tester.tap(find.byKey(const ValueKey('pad_0')));
      }
      if (match.left[1] > 0 && match.cooldown[1] <= 0) {
        final l1 = PigeonMatch.launchers[1];
        final p1 = match.pigeon;
        final want1 = atan2(p1.y - l1[1], p1.x - l1[0]);
        var d1 = match.aim(1) - want1;
        while (d1 > pi) { d1 -= 2 * pi; }
        while (d1 < -pi) { d1 += 2 * pi; }
        if (d1.abs() > 0.6) await tester.tap(find.byKey(const ValueKey('pad_1')));
      }
      if (!shotMid && match.fed[0] >= 1) {
        shotMid = true;
        await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/pigeon_fed.png'));
      }
    }
    expect(match.over, true);
    expect(match.fed[0], greaterThan(match.fed[1]));
    expect(match.winner, 0);
    await tester.pump(const Duration(milliseconds: 600));
    final recorded = await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 150));
      return ResultsService.instance.load();
    });
    expect(recorded!.length, 1);
    expect(recorded.first.game, 'أطعم الحمامة');
    expect(recorded.first.winner, 'لاعب 1');
    await tester.pump(const Duration(seconds: 2));
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/pigeon_win.png'));
    await settle(tester);
  });

  testWidgets('practice: no winner, nothing recorded', (tester) async {
    await open(tester);
    await tester.tap(find.text('لاعب واحد'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 100));
    final match = m(tester);
    for (var i = 0; i < 12000 && !match.over; i++) {
      await tester.pump(const Duration(milliseconds: 33));
      if (match.left[0] > 0 && match.cooldown[0] <= 0) {
        await tester.tap(find.byKey(const ValueKey('pad_0')));
      }
    }
    await tester.pump(const Duration(milliseconds: 600));
    expect(match.over, true);
    expect(find.textContaining('أطعمت الحمامة'), findsOneWidget);
    final rec = await tester.runAsync(() => ResultsService.instance.load());
    expect(rec, isEmpty);
    await settle(tester);
  });
}
