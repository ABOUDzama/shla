import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shella/games/offline/catch_game.dart';
import 'package:shella/games/offline/reaction_game.dart';
import 'package:shella/games/offline/sumo_game.dart';
import 'package:shella/games/offline/tap_race_game.dart';
import 'package:shella/games/offline/touch_ball_game.dart';

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
    testWidgets('sprint tap counts match input exactly', (tester) async {
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
      await tester.pump(const Duration(milliseconds: 3500));
      expect(find.textContaining('دوسوا'), findsOneWidget);

      // 4 taps with a frame after each must show exactly 4
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('لاعب 1'));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('4'), findsOneWidget);

      // 3 rapid taps without frames between must show exactly 3
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('لاعب 2'), warnIfMissed: false);
      }
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('3'), findsOneWidget);
      await flushFontCallbacks(tester);
      await settleDown(tester);
    });


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

  group('سومو الشلة widget', () {
    testWidgets('2p: countdown ignores taps, shove-out win, replay',
        (tester) async {
      tester.view.physicalSize = const Size(412, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await warmGoogleFonts(tester);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamilyFallback: const ['Noto Color Emoji']),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: SumoGame(),
        ),
      ));
      await flushFontCallbacks(tester);
      await startFromIntro(tester);

      // countdown: both zones say wait, taps are ignored by the logic
      expect(find.textContaining('استنى البداية'), findsWidgets);
      await tester.tap(find.text('لاعب 1'), warnIfMissed: false);
      await tester.pump();
      expect(find.textContaining('استنى البداية'), findsWidgets);

      // 3 one-second countdown ticks reach the fight
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.textContaining('دووووس'), findsWidgets);

      // shove the ring fully out: 51 taps x 0.02 push wins for player 1
      for (var i = 0; i < 55; i++) {
        await tester.tap(find.text('لاعب 1'), warnIfMissed: false);
      }
      await tester.pump();
      expect(find.textContaining('لاعب 1 كسب'), findsWidgets);

      // replay starts a fresh countdown
      await tester.tap(find.text('العب تاني'));
      await tester.pump();
      expect(find.textContaining('استنى البداية'), findsWidgets);
      await flushFontCallbacks(tester);
      await settleDown(tester);
    });
  });

  group('اقطفها widget', () {
    testWidgets('2p: catch scoring, wrong-color taps, match win, replay',
        (tester) async {
      tester.view.physicalSize = const Size(412, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await warmGoogleFonts(tester);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamilyFallback: const ['Noto Color Emoji']),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: CatchGame(),
        ),
      ));
      await flushFontCallbacks(tester);
      await startFromIntro(tester);
      await tester.tap(find.text('2'));
      await tester.pump();

      // tap zone 1 every 100ms: scores when the fish crosses the zone's
      // arc, wrong-color taps cost nothing; first to 5 wins the match
      var sawCatch = false;
      var sawWrong = false;
      for (var i = 0;
          i < 300 && find.textContaining('كسب الماتش').evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('لاعب 1'), warnIfMissed: false);
        await tester.pump();
        if (find.textContaining('لاعب 1 قطفها').evaluate().isNotEmpty) {
          sawCatch = true;
        }
        if (find.textContaining('غلط اللون').evaluate().isNotEmpty) {
          sawWrong = true;
        }
      }
      expect(sawCatch, isTrue, reason: 'a scoring catch must register');
      expect(sawWrong, isTrue, reason: 'wrong-color taps must register');
      expect(find.textContaining('كسب الماتش'), findsOneWidget);

      // replay resets scores for the same player count
      await tester.tap(find.text('ماتش جديد'));
      await tester.pump();
      expect(find.textContaining('لاعب 1: 0'), findsOneWidget);
      await flushFontCallbacks(tester);
      await settleDown(tester);
    });

    testWidgets('4p: four zones render and taps register', (tester) async {
      tester.view.physicalSize = const Size(412, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await warmGoogleFonts(tester);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamilyFallback: const ['Noto Color Emoji']),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: CatchGame(),
        ),
      ));
      await flushFontCallbacks(tester);
      await startFromIntro(tester);
      await tester.tap(find.text('4'));
      await tester.pump();
      for (final label in ['لاعب 1', 'لاعب 2', 'لاعب 3', 'لاعب 4']) {
        expect(find.text(label), findsOneWidget);
      }
      // a tap always updates the banner (catch or wrong color)
      await tester.tap(find.text('لاعب 4'));
      await tester.pump();
      final outcome = find
          .textContaining('قطفها!')
          .evaluate()
          .isNotEmpty ||
          find.textContaining('غلط اللون').evaluate().isNotEmpty;
      expect(outcome, isTrue);
      await flushFontCallbacks(tester);
      await settleDown(tester);
    });
  });

  group('كورة اللمسة widget', () {
    /// The ball is the only circular Container in the arena.
    Finder ballCircle() => find.byWidgetPredicate((w) =>
        w is Container &&
        w.constraints != null &&
        w.constraints!.maxWidth == 80 &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).shape == BoxShape.circle);

    /// Owner index parsed from the round banner 'كورة لاعب N!'.
    int? bannerOwner(WidgetTester tester) {
      final f = find.textContaining('كورة لاعب');
      if (f.evaluate().isEmpty) return null;
      final data = (tester.widget(f.first) as Text).data ?? '';
      final m = RegExp(r'كورة لاعب (\d)').firstMatch(data);
      return m == null ? null : int.parse(m.group(1)!) - 1;
    }

    /// Zone of the ball's rendered center inside its arena Stack, using
    /// the same quadrant mapping as the game (2p: top/bottom halves;
    /// 3p: top-left/top-right/bottom; 4p: quadrants).
    int ballZone(WidgetTester tester, int players) {
      final stack =
          find.ancestor(of: ballCircle(), matching: find.byType(Stack));
      final arena = tester.getRect(stack.first);
      final c = tester.getCenter(ballCircle());
      final top = c.dy < arena.center.dy;
      final left = c.dx < arena.center.dx;
      if (players == 2) return top ? 0 : 1;
      if (players == 3) return top ? (left ? 0 : 1) : 2;
      return top ? (left ? 0 : 1) : (left ? 2 : 3);
    }
    testWidgets('2p: owner taps score, match win, replay', (tester) async {
      tester.view.physicalSize = const Size(412, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await warmGoogleFonts(tester);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamilyFallback: const ['Noto Color Emoji']),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: TouchBallGame(),
        ),
      ));
      await flushFontCallbacks(tester);
      await startFromIntro(tester);
      await tester.tap(find.text('2 لاعبين'));
      await tester.pump();

      bool live() => ballCircle().evaluate().isNotEmpty;
      bool over() => find.textContaining('كسب الماتش').evaluate().isNotEmpty;

      var rounds = 0;
      while (!over() && rounds < 90) {
        // wait for a live ball
        var waited = 0;
        while (!live() && !over() && waited < 60) {
          await tester.pump(const Duration(milliseconds: 100));
          waited++;
        }
        if (!live()) break;
        // step until the ball drifts into its owner's zone, then tap it
        var steps = 0;
        while (live() &&
            (bannerOwner(tester) == null ||
                ballZone(tester, 2) != bannerOwner(tester)) &&
            steps < 52) {
          await tester.pump(const Duration(milliseconds: 50));
          steps++;
        }
        if (live() &&
            bannerOwner(tester) != null &&
            ballZone(tester, 2) == bannerOwner(tester)) {
          await tester.tap(ballCircle());
          await tester.pump();
        }
        rounds++;
      }
      expect(over(), isTrue, reason: 'someone reaches 5 within 90 rounds');

      // replay restarts with the same players and zeroed scores
      await tester.tap(find.text('ماتش جديد'));
      await tester.pump();
      expect(find.text('1: 0'), findsOneWidget);
      expect(find.text('2: 0'), findsOneWidget);
      await flushFontCallbacks(tester);
      await settleDown(tester);
    });

    testWidgets('2p: wrong-zone tap is penalized with the right banner',
        (tester) async {
      tester.view.physicalSize = const Size(412, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await warmGoogleFonts(tester);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamilyFallback: const ['Noto Color Emoji']),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: TouchBallGame(),
        ),
      ));
      await flushFontCallbacks(tester);
      await startFromIntro(tester);
      await tester.tap(find.text('2 لاعبين'));
      await tester.pump();

      bool live() => ballCircle().evaluate().isNotEmpty;

      // within a few rounds a ball must be tappable while outside the
      // owner's zone; tapping it then is a penalty
      var tapped = false;
      for (var round = 0; round < 10 && !tapped; round++) {
        var waited = 0;
        while (!live() && waited < 60) {
          await tester.pump(const Duration(milliseconds: 100));
          waited++;
        }
        var steps = 0;
        while (live() &&
            (bannerOwner(tester) == null ||
                ballZone(tester, 2) == bannerOwner(tester)) &&
            steps < 52) {
          await tester.pump(const Duration(milliseconds: 50));
          steps++;
        }
        if (live() &&
            bannerOwner(tester) != null &&
            ballZone(tester, 2) != bannerOwner(tester)) {
          await tester.tap(ballCircle());
          await tester.pump();
          tapped = true;
        }
      }
      expect(tapped, isTrue, reason: 'a misaligned ball must occur');
      expect(find.textContaining('لمس كورة مش بتاعته'), findsOneWidget);
      await flushFontCallbacks(tester);
      await settleDown(tester);
    });

    testWidgets('4p: scoreboard renders four players and a tap resolves',
        (tester) async {
      tester.view.physicalSize = const Size(412, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await warmGoogleFonts(tester);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamilyFallback: const ['Noto Color Emoji']),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: TouchBallGame(),
        ),
      ));
      await flushFontCallbacks(tester);
      await startFromIntro(tester);
      await tester.tap(find.text('4 لاعبين'));
      await tester.pump();
      for (final row in ['1: 0', '2: 0', '3: 0', '4: 0']) {
        expect(find.text(row), findsOneWidget);
      }
      // wait for the ball, tap it, and verify the outcome matches reality
      var waited = 0;
      while (ballCircle().evaluate().isEmpty && waited < 60) {
        await tester.pump(const Duration(milliseconds: 100));
        waited++;
      }
      expect(ballCircle(), findsOneWidget);
      final owner = bannerOwner(tester);
      expect(owner, isNotNull);
      final good = ballZone(tester, 4) == owner;
      await tester.tap(ballCircle());
      await tester.pump();
      expect(
        find.textContaining(good ? 'لمسها في وقتها' : 'مش بتاعته'),
        findsOneWidget,
      );
      await flushFontCallbacks(tester);
      await settleDown(tester);
    });
  });
}
