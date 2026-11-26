import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shella/games/offline/catch_game.dart';
import 'package:shella/games/offline/reaction_game.dart';
import 'package:shella/games/offline/snake_arena_game.dart';
import 'package:shella/games/offline/tank_battle_game.dart';
import 'package:shella/games/offline/rhythm_game.dart';
import 'package:shella/services/audio_service.dart';
import 'package:shella/games/offline/tug_of_war_game.dart';
import 'package:shella/games/offline/snow_brawl_game.dart';
import 'package:shella/games/offline/coin_grab_game.dart';
import 'package:shella/games/offline/whack_mole_game.dart';
import 'package:shella/games/offline/sumo_game.dart';
import 'package:shella/games/offline/tap_race_game.dart';
import 'package:shella/games/offline/touch_ball_game.dart';

/// Mid-play visual proof captures for the five arcade games. Each test
/// drives the real UI into a live gameplay state and golden-captures it;
/// the PNGs are pixel-inspected before being trusted as proof.

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

Widget shell(Widget game) => MaterialApp(
      theme: ThemeData(fontFamilyFallback: const ['Noto Color Emoji']),
      home: Directionality(textDirection: TextDirection.rtl, child: game),
    );

Future<void> prep(WidgetTester tester, Widget game) async {
  tester.view.physicalSize = const Size(412, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await warmGoogleFonts(tester);
  await tester.pumpWidget(shell(game));
  await flushFontCallbacks(tester);
  await tester.tap(find.textContaining('ابدأ اللعبة'));
  await tester.pump();
}

Future<void> snap(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(Scaffold).first,
    matchesGoldenFile('goldens/play_$name.png'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => AudioService.mutedForTests = true);
  tearDown(() => AudioService.mutedForTests = false);

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

  testWidgets('proof: reaction green state 2p', (tester) async {
    await prep(tester, const ReactionGame());
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump();
    await tester.tap(find.text('لا'));
    await tester.pump();
    // wait for the green "دوس!" moment
    for (var i = 0; i < 40 && find.text('دوس!').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text('دوس!'), findsWidgets);
    // let the 120ms zone-color transition to lime finish before capture
    await tester.pump(const Duration(milliseconds: 300));
    await snap(tester, 'reaction_green_2p');
    await settleDown(tester);
  });

  testWidgets('proof: sumo mid-fight', (tester) async {
    await prep(tester, const SumoGame());
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump();
    await tester.tap(find.text('لا'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.textContaining('دووووس'), findsWidgets);
    // a few shoves so the ring is visibly off-center
    for (var i = 0; i < 8; i++) {
      await tester.tap(find.text('لاعب 1'), warnIfMissed: false);
    }
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('لاعب 2'), warnIfMissed: false);
    }
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await snap(tester, 'sumo_fight');
    await settleDown(tester);
  });

  testWidgets('proof: catch spinning ring 4p', (tester) async {
    await prep(tester, const CatchGame(randomSeed: 7));
    await tester.tap(find.text('4 لاعبين'));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(seconds: 1));
    await snap(tester, 'catch_spin_4p');
    await settleDown(tester);
  });

  testWidgets('proof: tap-race sprint 2p', (tester) async {
    await prep(tester, const TapRaceGame());
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 3500));
    expect(find.byKey(const ValueKey('clock')), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('لاعب 1'), warnIfMissed: false);
    }
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('لاعب 2'), warnIfMissed: false);
    }
    await tester.pump();
    await snap(tester, 'taprace_sprint_2p');
    await settleDown(tester);
  });

  testWidgets('proof: touch-ball live ball 4p', (tester) async {
    await prep(tester, const TouchBallGame(randomSeed: 7));
    await tester.tap(find.text('4 لاعبين'));
    // lay the arena out first (device gets this frame ~16ms after the tap),
    // then let the live ball drift across the arena
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.textContaining('كورة لاعب'), findsWidgets);
    await snap(tester, 'touchball_live_4p');
    await settleDown(tester);
  });
  testWidgets('proof: snake arena live 4p', (tester) async {
    await prep(tester, const SnakeArenaGame(randomSeed: 7));
    await tester.tap(find.text('4 لاعبين'));
    await tester.pump();
    // let the four snakes advance a few deterministic ticks
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.textContaining('لفّ'), findsWidgets);
    await snap(tester, 'snake_arena_live_4p');
    await settleDown(tester);
  });
  testWidgets('proof: tank battle live 4p', (tester) async {
    await prep(tester, const TankBattleGame(randomSeed: 7));
    await tester.tap(find.text('4 لاعبين'));
    await tester.pump();
    // players 1+3 hold to steer then release to fire; 2+4 quick-tap to fire
    final g1 = await tester.startGesture(
        tester.getCenter(find.text('لاعب 1')));
    final g3 = await tester.startGesture(
        tester.getCenter(find.text('لاعب 3')));
    await tester.pump(const Duration(milliseconds: 500));
    await g1.up();
    await g3.up();
    await tester.tap(find.text('لاعب 2'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('لاعب 4'));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await snap(tester, 'tank_battle_live_4p');
    await settleDown(tester);
  });
  testWidgets('proof: rhythm tap listening', (tester) async {
    AudioService.mutedForTests = true;
    addTearDown(() => AudioService.mutedForTests = false);
    await prep(tester, const RhythmGame(randomSeed: 7, maxLevels: 1));
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump();
    await tester.tap(find.text('دوس على الزرار 👆'));
    await tester.pump();
    await tester.tap(find.text('يلا ▶'));
    await tester.pump();
    // watch the pattern play out, then the listening phase starts
    await tester.pump(const Duration(milliseconds: 3500));
    expect(find.text('دورك! قلّد الإيقاع دلوقتي'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rhythm_tap_pad')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('rhythm_tap_pad')));
    // let the tap-flash timers settle before the snapshot
    await tester.pump(const Duration(milliseconds: 150));
    await snap(tester, 'rhythm_tap_listening');
    await settleDown(tester);
  });
  testWidgets('proof: tug of war live 4p', (tester) async {
    await prep(tester, const TugOfWarGame(randomSeed: 7));
    await tester.tap(find.text('4 لاعبين'));
    await tester.pump();
    await tester.tap(find.text('كل واحد لوحده 👤'));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.tap(find.text('لاعب 1 💪'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await snap(tester, 'tug_of_war_live_4p');
    await settleDown(tester);
  });
  testWidgets('proof: snow brawl live 4p', (tester) async {
    await prep(tester, const SnowBrawlGame(randomSeed: 7));
    await tester.tap(find.text('4 لاعبين'));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.tap(find.text('لاعب 1 ❄'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await snap(tester, 'snow_brawl_live_4p');
    await settleDown(tester);
  });
  testWidgets('proof: coin grab live 4p', (tester) async {
    await prep(tester, const CoinGrabGame(randomSeed: 7));
    await tester.tap(find.text('4 لاعبين'));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.tap(find.byKey(const ValueKey('pad_0')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await snap(tester, 'coin_grab_live_4p');
    await settleDown(tester);
  });
  testWidgets('proof: whack mole live 4p', (tester) async {
    await prep(tester, const WhackMoleGame(randomSeed: 7));
    await tester.tap(find.text('4 لاعبين'));
    await tester.pump();
    // let a few moles pop
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.tap(find.byKey(const Key('mole_grid_0')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await snap(tester, 'whack_mole_live_4p');
    await settleDown(tester);
  });
}
