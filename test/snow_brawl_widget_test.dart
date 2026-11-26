import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shella/games/offline/snow_brawl_game.dart';

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

Future<void> pumpUntil(WidgetTester tester, Finder finder,
    {int maxMillis = 8000, int stepMillis = 250}) async {
  var elapsed = 0;
  while (elapsed < maxMillis) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(Duration(milliseconds: stepMillis));
    elapsed += stepMillis;
  }
  throw TestFailure('finder not found after ${maxMillis}ms: $finder');
}

Future<void> boot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await warmGoogleFonts(tester);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(fontFamilyFallback: const ['Noto Color Emoji']),
    home: const Directionality(
      textDirection: TextDirection.rtl,
      child: SnowBrawlGame(randomSeed: 7),
    ),
  ));
  await flushFontCallbacks(tester);
  await pumpUntil(tester, find.textContaining('ابدأ اللعبة'));
  await tester.tap(find.textContaining('ابدأ اللعبة'));
  await tester.pump();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('snow brawl: intro starts to player picker incl. solo', (tester) async {
    await boot(tester);
    expect(find.text('كام لاعب؟'), findsOneWidget);
    expect(find.text('لاعب واحد'), findsOneWidget);
    expect(find.text('2 لاعبين'), findsOneWidget);
    expect(find.text('3 لاعبين'), findsOneWidget);
    expect(find.text('4 لاعبين'), findsOneWidget);
    await flushFontCallbacks(tester);
    await settleDown(tester);
  });

  testWidgets('snow brawl: 2p start shows two turn buttons and scores',
      (tester) async {
    await boot(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump();
    expect(find.text('نضيف بوتات؟'), findsOneWidget);
    await tester.tap(find.text('لا'));
    await tester.pump();
    expect(find.text('لاعب 1 ❄'), findsOneWidget);
    expect(find.text('لاعب 2 ❄'), findsOneWidget);
    expect(find.text('لاعب 3 ❄'), findsNothing);
    expect(find.text('لاعب 1: 3'), findsOneWidget);
    await flushFontCallbacks(tester);
    await settleDown(tester);
  });

  testWidgets('snow brawl: 4p start shows four turn buttons', (tester) async {
    await boot(tester);
    await tester.tap(find.text('4 لاعبين'));
    await tester.pump();
    for (var i = 1; i <= 4; i++) {
      expect(find.text('لاعب $i ❄'), findsOneWidget);
    }
    await flushFontCallbacks(tester);
    await settleDown(tester);
  });

  testWidgets('snow brawl: tapping turn stays stable in live play',
      (tester) async {
    await boot(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump();
    await tester.tap(find.text('لا'));
    await tester.pump();
    await tester.tap(find.text('لاعب 1 ❄'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.byType(SnowBrawlGame), findsOneWidget);
    await flushFontCallbacks(tester);
    await settleDown(tester);
  });

  testWidgets('snow brawl: bots fill to 4 and throw on their own', (tester) async {
    await boot(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump();
    await tester.tap(find.text('اه 🤖'));
    await tester.pump();
    final state = tester.state(find.byType(SnowBrawlGame)) as dynamic;
    final m = state.debugMatch;
    expect(m.playerCount, 4);
    expect(m.botSeats, {2, 3});
    for (var i = 0; i < 60 && m.throws[2] + m.throws[3] == 0; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(m.throws[2] + m.throws[3], greaterThan(0));
    await flushFontCallbacks(tester);
    await settleDown(tester);
  });

  testWidgets('snow brawl: solo practice is 10 throws at a dummy, no forts lost', (tester) async {
    await boot(tester);
    await tester.tap(find.text('لاعب واحد'));
    await tester.pump();
    await tester.tap(find.text('لا'));
    await tester.pump();
    final state = tester.state(find.byType(SnowBrawlGame)) as dynamic;
    final m = state.debugMatch;
    expect(m.playerCount, 1);
    expect(find.text('لاعب 1 ❄'), findsOneWidget);
    expect(find.text('لاعب 2 ❄'), findsNothing);
    // throw 10 times regardless of power; hp untouched, round ends
    for (var t = 0; t < 10; t++) {
      await tester.tap(find.text('لاعب 1 ❄'));
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(m.throws[0], 10);
    expect(m.hp[0], m.fortHp);
    expect(m.isOver, isTrue);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('من 10'), findsOneWidget);
    await flushFontCallbacks(tester);
    await settleDown(tester);
  });
}
