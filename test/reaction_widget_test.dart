import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/games/offline/reaction_game.dart';
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
    final base = tester.binding.clock.now();
    reactionNow = () => tester.binding.clock.now().difference(base);
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(textDirection: TextDirection.rtl, child: ReactionGame(randomSeed: 3)),
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

  ReactionMatch m(WidgetTester t) =>
      (t.state(find.byType(ReactionGame)) as dynamic).debugMatch as ReactionMatch;
  bool green(WidgetTester t) => (t.state(find.byType(ReactionGame)) as dynamic).debugGreen as bool;

  Future<void> waitGreen(WidgetTester tester) async {
    for (var i = 0; i < 80 && !green(tester); i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(green(tester), true);
  }

  Future<void> start(WidgetTester tester, String players, String bots) async {
    await open(tester);
    await tester.tap(find.text(players));
    await tester.pump(const Duration(milliseconds: 100));
    if (bots.isNotEmpty) {
      await tester.tap(find.text(bots));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('2 players: early tap is a false start, tap on green scores that zone only', (tester) async {
    await start(tester, '2 لاعبين', 'لا');
    final match = m(tester);
    expect(match.playerCount, 2);
    expect(find.text('استنى الأخضر'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('zone_1')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(match.scores, [0, 0]);
    expect(find.textContaining('بدري'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1700));
    await waitGreen(tester);
    expect(find.text('دوس!'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await tester.pump(const Duration(milliseconds: 50));
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/reaction_green.png'));
    await tester.tap(find.byKey(const ValueKey('zone_1')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(match.scores, [0, 1]);
    expect(find.textContaining('الأسرع'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('bots: "لا" adds none, "اه" fills to 4 and the bots win some rounds on their own', (tester) async {
    await start(tester, '2 لاعبين', 'لا');
    expect((tester.state(find.byType(ReactionGame)) as dynamic).debugBots, isEmpty);
    expect(m(tester).playerCount, 2);
    await settle(tester);
    await start(tester, '2 لاعبين', 'اه 🤖');
    expect(m(tester).playerCount, 4);
    expect((tester.state(find.byType(ReactionGame)) as dynamic).debugBots, {2, 3});
    // humans never tap: bots must score
    for (var i = 0; i < 400 && m(tester).scores[2] + m(tester).scores[3] == 0; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(m(tester).scores[2] + m(tester).scores[3], greaterThan(0));
    await settle(tester);
  });

  testWidgets('first to 5 wins, crown on that seat, result recorded', (tester) async {
    await start(tester, '2 لاعبين', 'لا');
    final match = m(tester);
    for (var r = 0; r < 5; r++) {
      await waitGreen(tester);
      await tester.pump(const Duration(milliseconds: 350)); // controlled test delay, not a human measurement
      await tester.tap(find.byKey(const ValueKey('zone_0')));
      await tester.pump(const Duration(milliseconds: 1700));
    }
    expect(match.matchWinner, 0);
    await tester.pump(const Duration(milliseconds: 600));
    final rec = await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 150));
      return ResultsService.instance.load();
    });
    expect(rec!.length, 1);
    expect(rec.first.game, 'أسرع رد فعل');
    expect(rec.first.winner, 'لاعب 1');
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('crown_0')), findsOneWidget);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/reaction_win.png'));
    await settle(tester);
  });

  testWidgets('practice: one big zone, shows reaction time in ms, records nothing', (tester) async {
    await start(tester, 'لاعب واحد', 'لا');
    expect(m(tester).playerCount, 1);
    await waitGreen(tester);
    await tester.pump(const Duration(milliseconds: 320)); // controlled test delay
    await tester.tap(find.byKey(const ValueKey('zone_0')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('ms'), findsOneWidget);
    final shown = RegExp(r'(\d+) ms').firstMatch(tester.widgetList<Text>(find.textContaining('ms')).first.data!)!.group(1)!;
    expect(int.parse(shown), inInclusiveRange(320, 420), reason: 'controlled 320ms delay plus pump granularity');
    final rec = await tester.runAsync(() => ResultsService.instance.load());
    expect(rec, isEmpty);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/reaction_practice.png'));
    await settle(tester);
  });
}
