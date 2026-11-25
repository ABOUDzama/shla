import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/games/offline/whack_mole_game.dart';
import 'package:shella/games/offline/whack_mole_logic.dart';
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
      home: Directionality(textDirection: TextDirection.rtl, child: WhackMoleGame(randomSeed: 3)),
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

  WhackMoleMatch m(WidgetTester t) =>
      (t.state(find.byType(WhackMoleGame)) as dynamic).debugMatch as WhackMoleMatch;

  Future<void> start(WidgetTester tester, String players, String bots) async {
    await open(tester);
    await tester.tap(find.text(players));
    await tester.pump(const Duration(milliseconds: 100));
    if (bots.isNotEmpty) {
      await tester.tap(find.text(bots));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  // real tap on the hole where a mole is up in player p's grid
  Future<bool> whackUp(WidgetTester tester, int p) async {
    final match = m(tester);
    for (var h = 0; h < 4; h++) {
      if (match.isUp(p, h)) {
        final rect = tester.getRect(find.byKey(Key('mole_grid_$p')));
        final pos = Offset(
          rect.left + rect.width * (h % 2 == 0 ? 0.25 : 0.75),
          rect.top + rect.height * (h ~/ 2 == 0 ? 0.25 : 0.75),
        );
        await tester.tapAt(pos);
        return true;
      }
    }
    return false;
  }

  testWidgets('every player gets their own moles at the same rate; tap scores only the own grid', (tester) async {
    await start(tester, '2 لاعبين', 'لا');
    final match = m(tester);
    var seen = [0, 0];
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      for (var p = 0; p < 2; p++) {
        if ([0, 1, 2, 3].any((h) => match.isUp(p, h))) seen[p]++;
      }
    }
    expect(seen[0], greaterThan(60));
    expect(seen[1], greaterThan(60));
    var got = false;
    for (var i = 0; i < 100 && !got; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      got = await whackUp(tester, 0);
    }
    expect(got, true);
    expect(match.scores[0], 1);
    expect(match.scores[1], 0);
    await tester.pump(const Duration(milliseconds: 120));
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/whack_play.png'));
    await settle(tester);
  });

  testWidgets('bots: "لا" adds none, "اه" fills to 4 and bots hit moles on their own', (tester) async {
    await start(tester, '2 لاعبين', 'لا');
    expect(m(tester).playerCount, 2);
    expect(m(tester).botSeats, isEmpty);
    await settle(tester);
    await start(tester, '2 لاعبين', 'اه 🤖');
    expect(m(tester).playerCount, 4);
    expect(m(tester).botSeats, {2, 3});
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(m(tester).scores[2] + m(tester).scores[3], greaterThan(0));
    expect(m(tester).scores[0] + m(tester).scores[1], 0);
    await settle(tester);
  });

  testWidgets('seat 1 whacks everything, wins at the timer: crown and result recorded', (tester) async {
    await start(tester, '2 لاعبين', 'لا');
    final match = m(tester);
    for (var i = 0; i < 900 && !match.isOver; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      if (!match.isOver) await whackUp(tester, 0);
    }
    expect(match.isOver, true);
    expect(match.winner(), 0);
    await tester.pump(const Duration(milliseconds: 600));
    final rec = await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 150));
      return ResultsService.instance.load();
    });
    expect(rec!.length, 1);
    expect(rec.first.game, 'اضرب الخلد');
    expect(rec.first.winner, 'لاعب 1');
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('crown_0')), findsOneWidget);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/whack_win.png'));
    await settle(tester);
  });

  testWidgets('practice: one grid, no winner, nothing recorded', (tester) async {
    await start(tester, 'لاعب واحد', 'لا');
    final match = m(tester);
    expect(match.playerCount, 1);
    for (var i = 0; i < 900 && !match.isOver; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      if (!match.isOver) await whackUp(tester, 0);
    }
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('ضربت'), findsWidgets);
    final rec = await tester.runAsync(() => ResultsService.instance.load());
    expect(rec, isEmpty);
    await settle(tester);
  });
}
