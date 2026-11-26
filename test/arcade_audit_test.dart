import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/services/settings_service.dart';
import 'package:shella/games/offline/reaction_game.dart';
import 'package:shella/games/offline/snake_arena_game.dart';
import 'package:shella/games/offline/tank_battle_game.dart';
import 'package:shella/games/offline/tug_of_war_game.dart';
import 'package:shella/games/offline/snow_brawl_game.dart';
import 'package:shella/games/offline/whack_mole_game.dart';
import 'package:shella/games/offline/chicken_run_game.dart';
import 'package:shella/games/offline/car_race_game.dart';
import 'package:shella/games/offline/micro_racers_game.dart';
import 'package:shella/games/offline/flick_soccer_game.dart';
import 'package:shella/games/offline/goal_rush_game.dart';
import 'package:shella/games/offline/pigeon_game.dart';
import 'package:shella/games/offline/coin_grab_game.dart';
import 'package:shella/games/offline/sumo_game.dart';
import 'package:shella/games/offline/catch_game.dart';
import 'package:shella/games/offline/tap_race_game.dart';
import 'package:shella/games/offline/touch_ball_game.dart';
import 'package:shella/games/offline/rhythm_game.dart';
import 'package:shella/games/offline/ludo_game.dart';
import 'package:shella/games/offline/croc_game.dart';
import 'package:shella/games/offline/flappy_game.dart';
import 'package:shella/games/offline/minigolf_game.dart';
import 'package:shella/games/offline/obstacle_game.dart';
import 'package:shella/games/offline/ballshoot_game.dart';
import 'package:shella/games/offline/penguins_game.dart';
import 'package:shella/games/offline/orbit_game.dart';
import 'package:shella/games/offline/koala_game.dart';

/// ١٢٣٤ arcade audit: pumps every arcade game, enters gameplay, simulates a
/// few seconds of play and captures pixel proof to test/goldens/audit_*.png.
/// Layout overflows are recorded per game in test/goldens/audit_report.txt.
void main() {
  final boundaryKey = GlobalKey();
  final report = <String>[];

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'sound_enabled': false});
    await SettingsService.init();
    await SettingsService.setUserName('أحمد');
    await SettingsService.savePlayersProfiles([
      {'name': 'منى', 'avatar': ''},
      {'name': 'كريم', 'avatar': ''},
      {'name': 'سارة', 'avatar': ''},
    ]);
    for (final name in [
      'Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black',
    ]) {
      final bytes = await File('assets/fonts/Cairo-$name.ttf').readAsBytes();
      final loader = FontLoader('Cairo')
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
    final emojiBytes = await File('test/fonts_NotoColorEmoji.ttf').readAsBytes();
    final emojiLoader = FontLoader('Noto Color Emoji')
      ..addFont(Future.value(ByteData.sublistView(emojiBytes)));
    await emojiLoader.load();
    final pmBytes =
        await File('test/fonts_PermanentMarker-Regular.ttf').readAsBytes();
    final pmLoader = FontLoader('Permanent Marker')
      ..addFont(Future.value(ByteData.sublistView(pmBytes)));
    await pmLoader.load();
    final icons = await File(
      Platform.environment['HOME']! +
          '/sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytes();
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons)));
    await iconLoader.load();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final ch in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
      'dev.fluttercommunity.plus/sensors/method',
      'dev.fluttercommunity.plus/sensors/accelerometer',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(ch), (call) async => null);
    }
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (call) async => <String>['none'],
    );
  });

  tearDownAll(() {
    File('test/goldens/audit_report.txt').writeAsBytesSync(
      Uint8List.fromList(report.join('\n').codeUnits),
    );
  });

  Future<void> pumpSmall(WidgetTester tester, Widget game) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamilyFallback: const ['Noto Color Emoji']),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: RepaintBoundary(key: boundaryKey, child: game),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 60));
  }

  Future<void> flushFontCallbacks(WidgetTester tester) async {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await tester.pump();
  }

  Future<void> fixedPumps(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  Future<void> tapIf(WidgetTester tester, Finder f) async {
    if (f.evaluate().isEmpty) return;
    await tester.ensureVisible(f.first);
    await fixedPumps(tester, 2);
    await tester.tap(f.first, warnIfMissed: false);
    await fixedPumps(tester);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await fixedPumps(tester, 2);
    final boundary = boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2.0));
    final byteData =
        await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
    File('test/goldens/audit_$name.png')
        .writeAsBytesSync(byteData!.buffer.asUint8List());
  }

  Future<void> play(WidgetTester tester, String key, Widget game) async {
    await pumpSmall(tester, game);
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await flushFontCallbacks(tester);
    await capture(tester, '${key}_setup');
    // pick 2 players by any common label
    for (final label in ['2 لاعبين', 'لاعبين 2', '2']) {
      if (find.text(label).evaluate().isNotEmpty) {
        await tapIf(tester, find.text(label).first);
        break;
      }
    }
    // answer the bots prompt when present (yes = exercise bot code)
    final yesBot = find.text('اه').evaluate().isNotEmpty
        ? find.text('اه')
        : find.text('أه');
    if (yesBot.evaluate().isNotEmpty) {
      await tapIf(tester, yesBot.first);
    } else {
      await tapIf(tester, find.text('لا'));
    }
    // common start buttons inside games
    for (final label in ['ابدأ', 'يلا', 'ابدأ الجولة', 'بدء', 'GO', 'يلا نلعب']) {
      if (find.text(label).evaluate().isNotEmpty) {
        await tapIf(tester, find.text(label).first);
        break;
      }
    }
    tester.takeException();
    // let the game run ~2s with some generic taps to simulate play
    for (var i = 0; i < 6; i++) {
      await tester.tapAt(const Offset(120, 400));
      await tester.pump(const Duration(milliseconds: 160));
      await tester.tapAt(const Offset(240, 400));
      await tester.pump(const Duration(milliseconds: 160));
    }
    await flushFontCallbacks(tester);
    await capture(tester, '${key}_play');
    // keep simulating to try to reach an end state
    for (var i = 0; i < 10; i++) {
      await tester.tapAt(const Offset(120, 380));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tapAt(const Offset(240, 380));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await capture(tester, '${key}_late');
    final seen = <String>[];
    Object? e;
    while ((e = tester.takeException()) != null) {
      seen.add(e.toString());
    }
    final overflows =
        seen.where((m) => m.contains('overflowed') || m.contains('RenderFlex'));
    report.add(
        '$key: ${overflows.isEmpty ? 'ok' : 'OVERFLOW: ${overflows.first.take(160)}'}');
  }

  final games = <String, Widget>{
    'reaction': const ReactionGame(),
    'snake': const SnakeArenaGame(),
    'tank': const TankBattleGame(),
    'tug': const TugOfWarGame(),
    'snow': const SnowBrawlGame(),
    'whack': const WhackMoleGame(),
    'chicken': const ChickenRunGame(),
    'carrace': const CarRaceGame(),
    'micro': const MicroRacersGame(),
    'flick': const FlickSoccerGame(),
    'goalrush': const GoalRushGame(),
    'pigeon': const PigeonGame(),
    'coin': const CoinGrabGame(),
    'sumo': const SumoGame(),
    'catch': const CatchGame(),
    'taprace': const TapRaceGame(),
    'touchball': const TouchBallGame(),
    'rhythm': const RhythmGame(),
    'ludo': const LudoGameScreen(),
    'croc': const CrocGameScreen(),
    'flappy': const FlappyGameScreen(),
    'golf': const MiniGolfGameScreen(),
    'obstacle': const ObstacleGameScreen(),
    'ballshoot': const BallShootGameScreen(),
    'penguins': const PenguinsGameScreen(),
    'orbit': const OrbitGameScreen(),
    'koala': const KoalaGameScreen(),
  };

  for (final entry in games.entries) {
    testWidgets('audit: ${entry.key}', (tester) async {
      await play(tester, entry.key, entry.value);
    });
  }
}

extension on String {
  String take(int n) => length <= n ? this : substring(0, n);
}
