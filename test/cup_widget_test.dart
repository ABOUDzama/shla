import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shella/screens/arcade_section_screen.dart';
import 'package:shella/screens/cup/cup_screen.dart';
import 'package:shella/screens/cup/cup_setup_screen.dart';
import 'package:shella/services/cup_service.dart';
import 'package:shella/services/results_service.dart';
import 'package:shella/services/settings_service.dart';

/// Same google_fonts warm-up the other golden/widget tests use, so the
/// async Cairo registration finishes before the tree exists.
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await SettingsService.init();
    for (final name in [
      'Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black'
    ]) {
      final bytes =
          await File('assets/fonts/Cairo-$name.ttf').readAsBytes();
      final loader = FontLoader('Cairo')
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
    final icons = await File(Platform.environment['HOME']! +
            '/sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
        .readAsBytes();
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons)));
    await iconLoader.load();
    final emojiBytes =
        await File('test/fonts_NotoColorEmoji.ttf').readAsBytes();
    final emojiLoader = FontLoader('Noto Color Emoji')
      ..addFont(Future.value(ByteData.sublistView(emojiBytes)));
    await emojiLoader.load();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CupService.instance.endCup();
  });

  /// Decode the cover/avatar assets the cup screens show, the same way the
  /// other golden tests do it.
  Future<void> precacheArt(WidgetTester tester, Finder contextOf) async {
    final ctx = tester.element(contextOf);
    await tester.runAsync(() async {
      for (final path in ArcadeSectionScreen.covers.values) {
        await precacheImage(AssetImage(path), ctx);
      }
      for (final a in const [
        'assets/avatars/card_blue.png',
        'assets/avatars/card_purple.png',
        'assets/avatars/card_yellow.png',
        'assets/avatars/card_hijab.png',
      ]) {
        await precacheImage(AssetImage(a), ctx);
      }
    });
    await tester.pump();
  }

  void size(WidgetTester tester) {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget app(Widget child) => MaterialApp(
        home: child,
        theme: ThemeData(fontFamily: 'Cairo'),
      );

  /// Records a win the way a game's victory screen does, then lets the
  /// cup's ResultsService listener fold it in.
  Future<void> winRound(WidgetTester tester, String winner) async {
    final game = CupService.instance.currentGame!;
    await tester.runAsync(() => ResultsService.instance
        .recordWin(game: game, winner: winner, roundId: ResultsService.newRoundId()));
    await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }

  testWidgets('setup screen: rounds, modes, golden', (tester) async {
    size(tester);
    await warmGoogleFonts(tester);
    await tester.pumpWidget(app(const CupSetupScreen()));
    await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 800)));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('كأس الشلة 🏆'), findsOneWidget);
    expect(find.text('عدد الجولات'), findsOneWidget);
    expect(find.text('عشوائية 🎲'), findsOneWidget);

    // Manual mode: the pick grid with covers, decoded, is the golden.
    await tester.tap(find.text('اختارها بنفسك'));
    await tester.pump();
    await precacheArt(tester, find.byType(CupSetupScreen));
    // Let the chip highlight animation finish.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('اختار 3 ألعاب (0/3)'), findsOneWidget);
    await expectLater(find.byType(CupSetupScreen),
        matchesGoldenFile('goldens/cup_setup.png'));

    // The start button sits at the bottom of a lazy ListView: scroll to it.
    final startFinder = find.widgetWithText(ElevatedButton, 'ابدأ الكأس 🏆');
    await tester.dragUntilVisible(startFinder, find.byType(ListView),
        const Offset(0, -200));
    await tester.pump();

    // Manual mode disables start until exactly N games are picked.
    final startBtn2 = tester.widget<ElevatedButton>(startFinder);
    expect(startBtn2.onPressed, isNull);

    // Random mode enables it with no picks.
    await tester.ensureVisible(find.text('عشوائية 🎲'));
    await tester.pump();
    await tester.tap(find.text('عشوائية 🎲'), warnIfMissed: false);
    await tester.pump();
    await tester.dragUntilVisible(startFinder, find.byType(ListView),
        const Offset(0, -200));
    await tester.pump();
    final startBtn = tester.widget<ElevatedButton>(startFinder);
    expect(startBtn.onPressed, isNotNull);
  });

  testWidgets('arcade tab shows the cup banner and resumes a running cup',
      (tester) async {
    size(tester);
    await warmGoogleFonts(tester);
    await tester.pumpWidget(app(const ArcadeSectionScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('كأس الشلة 🏆'), findsOneWidget);
    expect(find.textContaining('بطولة جولات'), findsOneWidget);

    await CupService.instance
        .start(rounds: 3, games: const ['سومو الشلة', 'اقطفها', 'سباق الدوس']);
    await tester.pump();
    expect(find.textContaining('الكأس شغال: الجولة 1 من 3'), findsOneWidget);
  });

  testWidgets('cup screen: round card, win folds into standings, golden',
      (tester) async {
    size(tester);
    await CupService.instance
        .start(rounds: 2, games: const ['سومو الشلة', 'اقطفها']);
    await CupService.instance.markRoundStarted();
    await warmGoogleFonts(tester);
    await tester.pumpWidget(app(const CupScreen()));
    await precacheArt(tester, find.byType(CupScreen));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('الجولة 1 من 2'), findsOneWidget);
    expect(find.text('سومو الشلة'), findsWidgets);
    expect(find.text('ابدأ الجولة'), findsOneWidget);
    expect(find.textContaining('لسه مفيش نقاط'), findsOneWidget);

    await winRound(tester, 'لاعب 2');
    expect(CupService.instance.points, {'لاعب 2': 1});
    expect(find.text('لاعب 2 👑'), findsOneWidget);
    expect(find.text('1 ⭐'), findsOneWidget);
    expect(find.text('الجولة 2 من 2'), findsOneWidget);

    await precacheArt(tester, find.byType(CupScreen));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await expectLater(
        find.byType(CupScreen), matchesGoldenFile('goldens/cup_round.png'));
  });

  testWidgets('champion card after the last round, golden', (tester) async {
    size(tester);
    await CupService.instance
        .start(rounds: 2, games: const ['سومو الشلة', 'اقطفها']);
    await CupService.instance.markRoundStarted();
    await warmGoogleFonts(tester);
    await tester.pumpWidget(app(const CupScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    await winRound(tester, 'لاعب 2');
    await CupService.instance.markRoundStarted();
    await winRound(tester, 'لاعب 2');

    expect(CupService.instance.finished, isTrue);
    await precacheArt(tester, find.byType(CupScreen));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.text('الكأس خلص!'), findsOneWidget);
    expect(find.text('بطل الكأس 👑'), findsOneWidget);
    expect(find.text('لاعب 2'), findsWidgets);
    expect(find.text('2 نقاط من 2 جولات'), findsOneWidget);

    await expectLater(find.byType(CupScreen),
        matchesGoldenFile('goldens/cup_champion.png'));
  });

  testWidgets('bot win round counts with no points and no champion',
      (tester) async {
    size(tester);
    await CupService.instance
        .start(rounds: 1, games: const ['اقطفها']);
    await CupService.instance.markRoundStarted();
    await warmGoogleFonts(tester);
    await tester.pumpWidget(app(const CupScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    await winRound(tester, CupService.botsLabel);
    expect(CupService.instance.finished, isTrue);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('الكأس بلا بطل 🤖'), findsOneWidget);
  });
}
