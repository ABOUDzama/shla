import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shella/games/offline/tank_battle_game.dart';
import 'package:shella/widgets/victory_friends.dart';
import 'package:shella/services/audio_service.dart';

Future<void> flushFontCallbacks(WidgetTester tester) async {
  await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
  await tester.pump();
}

Future<void> warmGoogleFonts(WidgetTester tester) async {
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Column(children: [
      for (final w in [
        FontWeight.w400, FontWeight.w500, FontWeight.w600,
        FontWeight.w700, FontWeight.w800, FontWeight.w900,
      ])
        Text('warm', style: GoogleFonts.cairo(fontWeight: w)),
    ]),
  ));
  await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
  await tester.pump();
}

Future<void> settleDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump(const Duration(milliseconds: 1));
}

Future<void> boot(WidgetTester tester, {int seed = 11}) async {
  tester.view.physicalSize = const Size(412, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await warmGoogleFonts(tester);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(fontFamilyFallback: const ['Noto Color Emoji']),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: TankBattleGame(randomSeed: seed),
    ),
  ));
  await flushFontCallbacks(tester);
}

dynamic stateOf(WidgetTester tester) =>
    tester.state(find.byType(TankBattleGame)) as dynamic;

void main() {
  setUp(() => AudioService.mutedForTests = true);
  tearDown(() => AudioService.mutedForTests = false);
  testWidgets('intro explains hold-to-steer release-to-fire and bots',
      (tester) async {
    await boot(tester);
    expect(find.textContaining('دوس مطوّل'), findsWidgets);
    expect(find.textContaining('بوتات'), findsWidgets);
    await tester.tap(find.textContaining('ابدأ اللعبة'));
    await tester.pump();
    expect(find.text('كام لاعب؟'), findsOneWidget);
    expect(find.text('لاعب واحد'), findsOneWidget);
    expect(find.text('4 لاعبين'), findsOneWidget);
    await settleDown(tester);
  });

  testWidgets('under 4 humans asks about bots; bots fill to 4 without pads',
      (tester) async {
    await boot(tester);
    await tester.tap(find.textContaining('ابدأ اللعبة'));
    await tester.pump();
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump();
    expect(find.text('نضيف بوتات؟'), findsOneWidget);
    await tester.tap(find.text('اه 🤖'));
    await tester.pump();
    final m = stateOf(tester).debugMatch;
    expect(m.playerCount, 4);
    expect(m.humanCount, 2);
    // only human pads exist
    expect(find.text('لاعب 1'), findsOneWidget);
    expect(find.text('لاعب 2'), findsOneWidget);
    expect(find.text('لاعب 3'), findsNothing);
    // bots actually play: advance and expect a bot shell or a kill
    await tester.pump(const Duration(seconds: 3));
    final botFired =
        (m.shells as List).any((s) => (s as dynamic).owner >= 2);
    expect(botFired || m.aliveCount < 4, isTrue);
    await settleDown(tester);
  });

  testWidgets('hold pad steers and release fires a shell', (tester) async {
    await boot(tester);
    await tester.tap(find.textContaining('ابدأ اللعبة'));
    await tester.pump();
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump();
    await tester.tap(find.text('لا'));
    await tester.pump();
    final m = stateOf(tester).debugMatch;
    expect(m.playerCount, 2);
    final center = tester.getCenter(find.text('لاعب 1'));
    final h0 = m.headings[0];
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 300));
    expect(m.headings[0], greaterThan(h0));
    await gesture.up();
    await tester.pump();
    expect(m.shells.length, 1);
    expect(m.shells.first.owner, 0);
    await settleDown(tester);
  });

  testWidgets('rematch fully resets match state', (tester) async {
    await boot(tester);
    await tester.tap(find.textContaining('ابدأ اللعبة'));
    await tester.pump();
    await tester.tap(find.text('3 لاعبين'));
    await tester.pump();
    await tester.tap(find.text('لا'));
    await tester.pump();
    stateOf(tester).debugForceWin(2);
    await tester.pump();
    expect(find.text('العبوا تاني 🎯'), findsOneWidget);
    await tester.tap(find.text('العبوا تاني 🎯'));
    await tester.pump();
    expect(find.text('كام لاعب؟'), findsOneWidget);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump();
    await tester.tap(find.text('لا'));
    await tester.pump();
    final m = stateOf(tester).debugMatch;
    expect(m.playerCount, 2);
    expect(m.aliveCount, 2);
    expect(m.shells, isEmpty);
    expect(m.deathTick, isEmpty);
    expect(m.winner, isNull);
    expect(m.tickCount, 0);
    await settleDown(tester);
  });

  testWidgets('solo practice: tag + countdown, no win verdict, explicit exit',
      (tester) async {
    await boot(tester);
    await tester.tap(find.textContaining('ابدأ اللعبة'));
    await tester.pump();
    await tester.tap(find.text('لاعب واحد'));
    await tester.pump();
    await tester.tap(find.text('لا'));
    await tester.pump();
    final m = stateOf(tester).debugMatch;
    expect(m.practice, isTrue);
    // practice tag with countdown is visible
    expect(find.textContaining('تدريب · باقي'), findsOneWidget);
    expect(find.text('إنهاء'), findsOneWidget);
    // let the match run a few seconds: no early win/draw screen
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.text('انتهت جولة التدريب 👏'), findsNothing);
    expect(find.text('مفيش ناجي! الكل اتدمر 💥'), findsNothing);
    expect(find.byType(VictoryFriends), findsNothing);
    // explicit exit returns to the player picker
    await tester.tap(find.text('إنهاء'));
    await tester.pump();
    expect(find.text('كام لاعب؟'), findsOneWidget);
    await settleDown(tester);
  });

  testWidgets('bot winner gets bots banner; human winner gets VictoryFriends',
      (tester) async {
    await boot(tester);
    await tester.tap(find.textContaining('ابدأ اللعبة'));
    await tester.pump();
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump();
    await tester.tap(find.text('اه 🤖'));
    await tester.pump();
    expect(stateOf(tester).debugMatch.playerCount, 4);
    // bot seat (index 3) wins: bots banner, no friend-victory flow
    stateOf(tester).debugForceWin(3);
    await tester.pump();
    expect(find.text('البوتات كسبوا 🤖'), findsOneWidget);
    expect(find.byType(VictoryFriends), findsNothing);
    // rematch, then a human seat wins: VictoryFriends flow appears
    await tester.tap(find.text('العبوا تاني 🎯'));
    await tester.pump();
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump();
    await tester.tap(find.text('اه 🤖'));
    await tester.pump();
    stateOf(tester).debugForceWin(1);
    await tester.pump();
    expect(find.byType(VictoryFriends), findsOneWidget);
    expect(find.text('البوتات كسبوا 🤖'), findsNothing);
    // crown is grounded in the winner seat (index 1), not the name text
    expect(find.byKey(const ValueKey('crown_1')), findsOneWidget);
    await settleDown(tester);
  });
}
