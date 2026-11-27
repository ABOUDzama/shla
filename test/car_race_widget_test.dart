import 'dart:io';
import 'dart:math' as _m;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/games/offline/car_race_game.dart';
import 'package:shella/games/offline/car_race_logic.dart';
import 'package:shella/services/results_service.dart';
import 'package:shella/services/audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => AudioService.mutedForTests = true);
  tearDown(() => AudioService.mutedForTests = false);
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    for (final name in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black']) {
      final bytes = await File('assets/fonts/Cairo-$name.ttf').readAsBytes();
      final loader = FontLoader('Cairo')..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
    final emojiBytes = await File('test/fonts_NotoColorEmoji.ttf').readAsBytes();
    final l = FontLoader('Noto Color Emoji')..addFont(Future.value(ByteData.sublistView(emojiBytes)));
    await l.load();
    final mi = await File('${Platform.environment['HOME']}/sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytes();
    final il = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(mi)));
    await il.load();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(textDirection: TextDirection.rtl, child: CarRaceGame(randomSeed: 3)),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await tester.pump();
    await tester.ensureVisible(find.text('ابدأ اللعبة 🚀'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('ابدأ اللعبة 🚀'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 600)));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  }

  CarRaceMatch m(WidgetTester t) =>
      (t.state(find.byType(CarRaceGame)) as dynamic).debugMatch as CarRaceMatch;

  testWidgets('4 players: holding a pad steers only that car; release goes straight', (tester) async {
    await open(tester);
    await tester.tap(find.text('4 لاعبين'));
    await tester.pump(const Duration(milliseconds: 100));
    final match = m(tester);
    expect(match.seats, 4);
    expect(match.botSeats, isEmpty);
    for (final s in [0, 1, 2, 3]) {
      expect(find.byKey(ValueKey('pad_${s}_l')), findsOneWidget);
      expect(find.byKey(ValueKey('pad_${s}_r')), findsOneWidget);
    }
    final h0 = match.cars[0].heading, h1 = match.cars[1].heading;
    final g = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('pad_0_r'))));
    await tester.pump(const Duration(milliseconds: 400));
    expect(match.cars[0].heading, greaterThan(h0 + 0.5));
    expect(match.cars[1].heading, h1, reason: 'other seat not steered');
    await g.up();
    final after = match.cars[0].heading;
    await tester.pump(const Duration(milliseconds: 400));
    expect(match.cars[0].heading, closeTo(after, 0.001));
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/car_race_play.png'));
    await settle(tester);
  });

  testWidgets('bots: "لا" adds none, "اه" fills to 4', (tester) async {
    await open(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(m(tester).seats, 2);
    expect(m(tester).botSeats, isEmpty);
    await settle(tester);
    await open(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('اه 🤖'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(m(tester).seats, 4);
    expect(m(tester).botSeats, {2, 3});
    await settle(tester);
  });

  testWidgets('a human finishes 3 laps by steering the pads: winner screen and result recorded', (tester) async {
    await open(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 100));
    final match = m(tester);
    // Real pad presses: a tiny autopilot reads the car and holds the right
    // pad (left when needed) like a person would.
    int? held;
    TestGesture? g;
    for (var i = 0; i < 3000 && !match.over; i++) {
      final c = match.cars[0];
      final target = CarRaceMatch.centerlinePoint(_ang(c) + 0.32);
      var d = _atan2(target.y - c.y, target.x - c.x) - c.heading;
      while (d > 3.14159) { d -= 6.28318; }
      while (d < -3.14159) { d += 6.28318; }
      final want = d.abs() < 0.08 ? 0 : (d > 0 ? 1 : -1);
      if (want != held) {
        await g?.up();
        g = null;
        held = want;
        if (want != 0) {
          g = await tester.startGesture(tester.getCenter(find.byKey(ValueKey('pad_0_${want < 0 ? 'l' : 'r'}'))));
        }
      }
      await tester.pump(const Duration(milliseconds: 33));
      if (i == 150) {
        await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/car_race_midlap.png'));
      }
    }
    await g?.up();
    expect(match.over, true, reason: 'pad-steered car finished 3 laps');
    expect(match.winner, 0);
    await tester.pump(const Duration(milliseconds: 600));
    final recorded = await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 150));
      return ResultsService.instance.load();
    });
    expect(recorded!.length, 1);
    expect(recorded.first.game, 'سباق العربيات');
    expect(recorded.first.winner, 'لاعب 1');
    await tester.pump(const Duration(seconds: 2));
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/car_race_win.png'));
    await settle(tester);
  });

  testWidgets('practice: 1 player "لا" shows no winner and records nothing', (tester) async {
    await open(tester);
    await tester.tap(find.text('لاعب واحد'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(m(tester).seats, 1);
    expect(m(tester).practice, true);
    m(tester).cars[0].theta = 3 * 2 * 3.14159265 + 0.01; // as if 3 laps are done
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('خلصت ٣ لفات'), findsOneWidget);
    final rec = await tester.runAsync(() => ResultsService.instance.load());
    expect(rec, isEmpty);
    await settle(tester);
  });
}

double _ang(Car c) => _atan2(c.y - CarRaceMatch.cy, c.x - CarRaceMatch.cx);
double _atan2(double y, double x) => _m.atan2(y, x);
double _cos(double a) => _m.cos(a);
double _sin(double a) => _m.sin(a);
