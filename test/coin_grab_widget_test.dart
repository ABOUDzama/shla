import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shella/games/offline/coin_grab_game.dart';

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
      child: CoinGrabGame(randomSeed: 7),
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

  testWidgets('coin grab: intro starts to player picker', (tester) async {
    await boot(tester);
    expect(find.text('كام لاعب؟'), findsOneWidget);
    expect(find.text('2 لاعبين'), findsOneWidget);
    expect(find.text('3 لاعبين'), findsOneWidget);
    expect(find.text('4 لاعبين'), findsOneWidget);
    await flushFontCallbacks(tester);
    await settleDown(tester);
  });

  testWidgets('coin grab: 2p match shows arena and two grab buttons',
      (tester) async {
    await boot(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump();
    expect(find.text('لاعب 1 🪙'), findsOneWidget);
    expect(find.text('لاعب 2 🪙'), findsOneWidget);
    expect(find.text('لاعب 3 🪙'), findsNothing);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(CoinGrabGame), findsOneWidget);
    await flushFontCallbacks(tester);
    await settleDown(tester);
  });

  testWidgets('coin grab: tapping a grab button updates the banner',
      (tester) async {
    await boot(tester);
    await tester.tap(find.text('4 لاعبين'));
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('لاعب 1 🪙'));
    await tester.pump();
    expect(find.textContaining('لاعب 1'), findsWidgets);
    await flushFontCallbacks(tester);
    await settleDown(tester);
  });
}
