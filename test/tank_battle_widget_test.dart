import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shella/games/offline/tank_battle_game.dart';

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

void main() {
  testWidgets('intro explains hold-to-steer release-to-fire', (tester) async {
    await boot(tester);
    expect(find.textContaining('دوس مطوّل'), findsWidgets);
    expect(find.textContaining('سيب الزرار'), findsWidgets);
    await tester.tap(find.textContaining('ابدأ اللعبة'));
    await tester.pump();
    expect(find.text('كام لاعب؟'), findsOneWidget);
    await settleDown(tester);
  });

  testWidgets('hold button steers and release fires a shell', (tester) async {
    await boot(tester);
    await tester.tap(find.textContaining('ابدأ اللعبة'));
    await tester.pump();
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump();
    expect(find.text('لاعب 1 🎯'), findsOneWidget);
    expect(find.text('لاعب 2 🎯'), findsOneWidget);

    final center = tester.getCenter(find.text('لاعب 1 🎯'));
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pump();
    expect(find.text('لاعب 1 ضرب! 💥'), findsOneWidget);
    await settleDown(tester);
  });

  testWidgets('elimination ends round and replay returns to picker',
      (tester) async {
    await boot(tester);
    await tester.tap(find.textContaining('ابدأ اللعبة'));
    await tester.pump();
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump();
    (tester.state(find.byType(TankBattleGame)) as dynamic).debugForceWin(0);
    await tester.pump();
    expect(find.text('العبوا تاني 🎯'), findsOneWidget);
    await tester.tap(find.text('العبوا تاني 🎯'));
    await tester.pump();
    expect(find.text('كام لاعب؟'), findsOneWidget);
    await settleDown(tester);
  });

  testWidgets('rematch fully resets match state', (tester) async {
    await boot(tester);
    await tester.tap(find.textContaining('ابدأ اللعبة'));
    await tester.pump();
    await tester.tap(find.text('3 لاعبين'));
    await tester.pump();
    // play a little: player 1 fires
    final g = await tester.startGesture(
        tester.getCenter(find.text('لاعب 1 🎯')));
    await tester.pump(const Duration(milliseconds: 200));
    await g.up();
    await tester.pump(const Duration(milliseconds: 200));
    (tester.state(find.byType(TankBattleGame)) as dynamic).debugForceWin(2);
    await tester.pump();
    // rematch
    await tester.tap(find.text('العبوا تاني 🎯'));
    await tester.pump();
    expect(find.text('كام لاعب؟'), findsOneWidget);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump();
    final m = ((tester.state(find.byType(TankBattleGame)) as dynamic)
        .debugMatch) as dynamic;
    expect(m.playerCount, 2);
    expect(m.aliveCount, 2);
    expect(m.shells, isEmpty);
    expect(m.destroyedAt, isEmpty);
    expect(m.winner, isNull);
    expect(m.tickCount, 0);
    // banner reset to the how-to hint
    expect(find.textContaining('دوس مطوّل'), findsWidgets);
    await settleDown(tester);
  });
}
