import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shella/games/offline/reaction_game.dart';
import 'package:shella/games/offline/tap_race_game.dart';

/// Pumps until [finder] matches, advancing fake time in small steps.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int maxMillis = 8000,
  int stepMillis = 250,
}) async {
  var elapsed = 0;
  while (elapsed < maxMillis) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(Duration(milliseconds: stepMillis));
    elapsed += stepMillis;
  }
  throw TestFailure('finder not found after ${maxMillis}ms: $finder');
}


Future<void> settleDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  // zero-duration fake timers only fire when fake time advances
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump(const Duration(milliseconds: 1));
}

/// Lets async font-load notifications settle so their transient callback
/// fires inside the test, not after teardown (known flutter_test artifact).
Future<void> flushFontCallbacks(WidgetTester tester) async {
  await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
  await tester.pump();
}


/// Builds throwaway texts in every Cairo weight so google_fonts finishes its
/// async family registration BEFORE the animated game tree exists; otherwise
/// the registration lands mid-frame and paint hits a TextPainter assert.
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

Future<void> startFromIntro(WidgetTester tester) async {
  await pumpUntil(tester, find.textContaining('ابدأ اللعبة'));
  await tester.tap(find.textContaining('ابدأ اللعبة'));
  await tester.pump();
}

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
    final emojiBytes =
        await File('test/fonts_NotoColorEmoji.ttf').readAsBytes();
    final emojiLoader = FontLoader('Noto Color Emoji')
      ..addFont(Future.value(ByteData.sublistView(emojiBytes)));
    await emojiLoader.load();
    final icons = await File(
      Platform.environment['HOME']! +
          '/sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytes();
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons)));
    await iconLoader.load();
  });

  group('أسرع رد فعل widget', () {
    testWidgets('2p: false start penalty, rounds, match win, replay',
        (tester) async {
      tester.view.physicalSize = const Size(412, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await warmGoogleFonts(tester);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamilyFallback: const ['Noto Color Emoji']),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: ReactionGame(),
        ),
      ));
      await flushFontCallbacks(tester);
      await startFromIntro(tester);
      await tester.tap(find.text('2'));
      await tester.pump();

      // false start while waiting
      expect(find.textContaining('استنى'), findsOneWidget);
      await tester.tap(find.text('لاعب 1'));
      await tester.pump();
      expect(find.textContaining('بدري'), findsOneWidget);
      expect(find.text('0 / 5'), findsWidgets); // never below zero

      // re-arms automatically after 1.5s
      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.textContaining('استنى'), findsOneWidget);

      // win 5 rounds as player 1 (bottom zone)
      for (var round = 0; round < 5; round++) {
        await pumpUntil(tester, find.text('دوس!'), maxMillis: 6000);
        await tester.tap(find.text('لاعب 1'));
        await tester.pump();
        if (round < 4) {
          expect(find.textContaining('الأسرع'), findsOneWidget);
          await tester.pump(const Duration(milliseconds: 1600));
        }
      }
      expect(find.textContaining('كسب الماتش'), findsOneWidget);

      // replay returns to picker (no timers pending in picker state)
      await tester.tap(find.text('العب تاني'));
      await tester.pump();
      expect(find.text('كام لاعب؟'), findsOneWidget);
      await flushFontCallbacks(tester);
      await settleDown(tester);
    });

    testWidgets('4p: all four zones render and register false start',
        (tester) async {
      tester.view.physicalSize = const Size(412, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await warmGoogleFonts(tester);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamilyFallback: const ['Noto Color Emoji']),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: ReactionGame(),
        ),
      ));
      await flushFontCallbacks(tester);
      await startFromIntro(tester);
      await tester.tap(find.text('4'));
      await tester.pump();
      for (final label in ['لاعب 1', 'لاعب 2', 'لاعب 3', 'لاعب 4']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('لاعب 4'));
      await tester.pump();
      expect(find.textContaining('لاعب 4 دوس بدري'), findsOneWidget);
      // let the 1.5s re-arm timer fire so no timer is pending at teardown
      await tester.pump(const Duration(milliseconds: 1600));
      await flushFontCallbacks(tester);
      await settleDown(tester);
    });
  });

  group('سباق الدوس widget', () {
    testWidgets('2p: countdown, sprint taps, rounds, match win',
        (tester) async {
      tester.view.physicalSize = const Size(412, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await warmGoogleFonts(tester);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamilyFallback: const ['Noto Color Emoji']),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: TapRaceGame(),
        ),
      ));
      await flushFontCallbacks(tester);
      await startFromIntro(tester);
      await tester.tap(find.text('2 لاعبين'));
      await tester.pump();

      // taps during countdown are ignored by logic; reach sprint
      await tester.tap(find.text('لاعب 1'));
      await tester.pump(const Duration(milliseconds: 3500));
      expect(find.textContaining('دوسوا'), findsOneWidget);

      for (var round = 0; round < 3; round++) {
        for (var i = 0; i < 10; i++) {
          await tester.tap(find.text('لاعب 1'), warnIfMissed: false);
        }
        for (var i = 0; i < 5; i++) {
          await tester.tap(find.text('لاعب 2'), warnIfMissed: false);
        }
        // 5-second sprint elapses, then round result shows
        await tester.pump(const Duration(milliseconds: 5500));
        await tester.pump(); // settle frame for the result banner
        if (round < 2) {
          expect(find.textContaining('كسب الجولة'), findsOneWidget);
          expect(find.textContaining('لاعب 1 كسب الجولة'), findsOneWidget);
          await tester.tap(find.text('الجولة الجاية'));
          await tester.pump(const Duration(milliseconds: 3500));
          expect(find.textContaining('دوسوا'), findsOneWidget);
        }
      }
      // third round win ends the match (best of 5, first to 3)
      expect(find.textContaining('كسب الماتش'), findsOneWidget);
      expect(find.text('ماتش جديد'), findsOneWidget);
      await flushFontCallbacks(tester);
      await settleDown(tester);
    });

    testWidgets('4p: four lanes render, taps counted per lane',
        (tester) async {
      tester.view.physicalSize = const Size(412, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await warmGoogleFonts(tester);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamilyFallback: const ['Noto Color Emoji']),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: TapRaceGame(),
        ),
      ));
      await flushFontCallbacks(tester);
      await startFromIntro(tester);
      await tester.tap(find.text('4 لاعبين'));
      await tester.pump(const Duration(milliseconds: 3500));
      expect(find.textContaining('دوسوا'), findsOneWidget);
      for (final label in ['لاعب 1', 'لاعب 2', 'لاعب 3', 'لاعب 4']) {
        expect(find.text(label), findsOneWidget);
      }
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('لاعب 4'), warnIfMissed: false);
      }
      await tester.pump(const Duration(milliseconds: 5500));
      await tester.pump(); // settle frame for the result banner
      expect(find.textContaining('لاعب 4 كسب الجولة'), findsOneWidget);
      await flushFontCallbacks(tester);
      await settleDown(tester);
    });
  });
}
