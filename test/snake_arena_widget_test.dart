import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shella/games/offline/snake_arena_game.dart';

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
      child: SnakeArenaGame(randomSeed: 7),
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

  testWidgets('snake arena: intro starts to player picker', (tester) async {
    await boot(tester);
    expect(find.text('كام لاعب؟'), findsOneWidget);
    expect(find.text('2 لاعبين'), findsOneWidget);
    expect(find.text('3 لاعبين'), findsOneWidget);
    expect(find.text('4 لاعبين'), findsOneWidget);
    await flushFontCallbacks(tester);
    await settleDown(tester);
  });

  testWidgets('snake arena: 2p start shows two turn buttons and scores',
      (tester) async {
    await boot(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump();
    expect(find.text('لاعب 1 لفّ 🐍'), findsOneWidget);
    expect(find.text('لاعب 2 لفّ 🐍'), findsOneWidget);
    expect(find.text('لاعب 3 لفّ 🐍'), findsNothing);
    expect(find.text('لاعب 1: 0'), findsOneWidget);
    await flushFontCallbacks(tester);
    await settleDown(tester);
  });

  testWidgets('snake arena: 4p start shows four turn buttons', (tester) async {
    await boot(tester);
    await tester.tap(find.text('4 لاعبين'));
    await tester.pump();
    for (var i = 1; i <= 4; i++) {
      expect(find.text('لاعب $i لفّ 🐍'), findsOneWidget);
    }
    await flushFontCallbacks(tester);
    await settleDown(tester);
  });

  testWidgets('snake arena: tapping turn stays stable in live play',
      (tester) async {
    await boot(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump();
    await tester.tap(find.text('لاعب 1 لفّ 🐍'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.byType(SnakeArenaGame), findsOneWidget);
    await flushFontCallbacks(tester);
    await settleDown(tester);
  });
}
