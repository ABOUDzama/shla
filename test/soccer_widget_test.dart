import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/widgets/avatar_picker_sheet.dart';
import 'package:shella/services/avatar_service.dart';
import 'package:shella/services/settings_service.dart';
import 'package:shella/games/offline/soccer_game.dart';
import 'package:shella/games/offline/soccer_logic.dart';
import 'package:shella/services/results_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    for (final name in [
      'Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black'
    ]) {
      final bytes = await File('assets/fonts/Cairo-$name.ttf').readAsBytes();
      final loader = FontLoader('Cairo')
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
    final icons = await File(
      Platform.environment['HOME']! +
          '/sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytes();
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons)));
    await iconLoader.load();
    final emojiBytes =
        await File('test/fonts_NotoColorEmoji.ttf').readAsBytes();
    final emojiLoader = FontLoader('Noto Color Emoji')
      ..addFont(Future.value(ByteData.sublistView(emojiBytes)));
    await emojiLoader.load();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(textDirection: TextDirection.rtl, child: SoccerGame(randomSeed: 3)),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await tester.pump();
    await tester.ensureVisible(find.text('ابدأ اللعبة 🚀'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('ابدأ اللعبة 🚀'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
  }

  SoccerMatch m(WidgetTester t) => (t.state(find.byType(SoccerGame)) as dynamic).debugMatch as SoccerMatch;

  testWidgets('4 players: pads steer, ball and clock move', (tester) async {
    await open(tester);
    await tester.tap(find.text('4 لاعبين'));
    await tester.pump(const Duration(milliseconds: 100));
    final match = m(tester);
    expect(match.players.length, 4);
    expect(match.botIndexes, isEmpty);
    expect(find.byKey(const ValueKey('pad_3_r')), findsOneWidget);
    final h0 = match.players[0].heading;
    final g = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('pad_0_r'))));
    await tester.pump(const Duration(milliseconds: 500));
    expect(match.players[0].heading, greaterThan(h0 + 0.5), reason: 'right pad turns seat 1');
    final h1 = match.players[1].heading; // seat 2 = logic index 2 in 2v2? seat order t0s0,t1s0
    await g.up();
    final hAfter = match.players[0].heading;
    await tester.pump(const Duration(milliseconds: 500));
    expect(match.players[0].heading, closeTo(hAfter, 0.01), reason: 'releasing goes straight');
    expect(match.timeLeft, lessThan(SoccerMatch.matchSeconds));
    expect(h1, isNotNull);
    await tester.pump(const Duration(milliseconds: 200));
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/soccer_play.png'));
  });

  testWidgets('bots rule: 2 players "لا" is 1v1 with no bots; "اه" adds bots', (tester) async {
    await open(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('نضيف بوتات؟'), findsOneWidget);
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(m(tester).players.length, 2);
    expect(m(tester).botIndexes, isEmpty);
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 600)));
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('bots rule: "اه" fills 2v2 with humans on opposite teams', (tester) async {
    await open(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('اه 🤖'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(m(tester).players.length, 4);
    expect(m(tester).botIndexes.length, 2);
    final seatPlayers = ((tester.state(find.byType(SoccerGame))) as dynamic).debugSeatPlayers as List<int>;
    expect(seatPlayers.map((i) => m(tester).players[i].team).toSet(), {0, 1}, reason: 'humans on opposite teams');
  });

  testWidgets('1 player "لا" is practice: frozen opponent, no winner recorded', (tester) async {
    await open(tester);
    await tester.tap(find.text('لاعب واحد'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(m(tester).botIndexes, isEmpty);
    expect(m(tester).frozenIndexes, {1});
    final y = m(tester).players[1].y;
    await tester.pump(const Duration(seconds: 1));
    expect(m(tester).players[1].y, y, reason: 'frozen opponent stays put');
    (tester.state(find.byType(SoccerGame)) as dynamic).debugForceScore(0, 3);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('جولة التدريب'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    final recorded = await tester.runAsync(() => ResultsService.instance.load());
    expect(recorded, isEmpty);
  });

  testWidgets('win: first to 3 -> victory screen and result recorded for the winning seat', (tester) async {
    await open(tester);
    await tester.tap(find.text('4 لاعبين'));
    await tester.pump(const Duration(milliseconds: 100));
    (tester.state(find.byType(SoccerGame)) as dynamic).debugForceScore(1, 3);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('لاعب 2 و لاعب 4'), findsWidgets);
    final recorded = await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      return ResultsService.instance.load();
    });
    expect(recorded!.length, 1);
    expect(recorded.first.game, 'كورة الشلة');
    await tester.pump(const Duration(seconds: 2));
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/soccer_win.png'));
  });
}
