import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/games/offline/coin_grab_game.dart';
import 'package:shella/games/offline/coin_grab_logic.dart';
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
      home: Directionality(textDirection: TextDirection.rtl, child: CoinGrabGame(randomSeed: 3)),
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

  CoinGrabMatch m(WidgetTester t) =>
      (t.state(find.byType(CoinGrabGame)) as dynamic).debugMatch as CoinGrabMatch;

  testWidgets('4 players: each pad belongs to its own seat only', (tester) async {
    await open(tester);
    await tester.tap(find.text('4 لاعبين'));
    await tester.pump(const Duration(milliseconds: 100));
    final match = m(tester);
    expect(match.seats, 4);
    expect(match.botSeats, isEmpty);
    await tester.tap(find.byKey(const ValueKey('pad_1')));
    await tester.pump(const Duration(milliseconds: 120));
    expect(match.cooldown[1], greaterThan(0));
    expect(match.cooldown[0], 0);
    await tester.tap(find.byKey(const ValueKey('pad_1')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(match.cooldown[1], greaterThan(0), reason: 'cooldown set by the tap');
    await tester.tap(find.byKey(const ValueKey('pad_3')));
    await tester.tap(find.byKey(const ValueKey('pad_0')));
    await tester.pump(const Duration(milliseconds: 250));
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/coin_grab_play.png'));
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

  bool onCoin(CoinGrabMatch match, int seat) {
    final t = match.tip(seat);
    return match.coins.any((c) => sqrt(pow(c.x - t.x, 2) + pow(c.y - t.y, 2)) < 0.04);
  }

  testWidgets('real pad taps on a coin score; winner screen and result recorded', (tester) async {
    await open(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 100));
    final match = m(tester);
    var shot = false;
    for (var i = 0; i < 3000 && !match.over; i++) {
      await tester.pump(const Duration(milliseconds: 33));
      if (match.cooldown[0] <= 0 && onCoin(match, 0)) {
        await tester.tap(find.byKey(const ValueKey('pad_0')));
      }
      if (!shot && match.scores[0] > 0) {
        shot = true;
        await tester.pump(const Duration(milliseconds: 100));
        await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/coin_grab_grab.png'));
      }
    }
    expect(match.over, true);
    expect(match.scores[0], greaterThan(0));
    expect(match.scores[1], 0);
    expect(match.winner, 0);
    await tester.pump(const Duration(milliseconds: 600));
    final recorded = await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 150));
      return ResultsService.instance.load();
    });
    expect(recorded!.length, 1);
    expect(recorded.first.game, 'لمّ الفلوس');
    expect(recorded.first.winner, 'لاعب 1');
    await tester.pump(const Duration(seconds: 2));
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/coin_grab_win.png'));
    await settle(tester);
  });

  testWidgets('practice: no winner, nothing recorded, clock ends it', (tester) async {
    await open(tester);
    await tester.tap(find.text('لاعب واحد'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 100));
    final match = m(tester);
    for (var i = 0; i < 3000 && !match.over; i++) {
      await tester.pump(const Duration(milliseconds: 33));
      if (match.cooldown[0] <= 0 && onCoin(match, 0)) {
        await tester.tap(find.byKey(const ValueKey('pad_0')));
      }
    }
    await tester.pump(const Duration(milliseconds: 600));
    expect(match.over, true);
    expect(find.textContaining('لمّيت'), findsOneWidget);
    final rec = await tester.runAsync(() => ResultsService.instance.load());
    expect(rec, isEmpty);
    await settle(tester);
  });
}
