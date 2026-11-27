import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/games/offline/micro_racers_game.dart';
import 'package:shella/games/offline/micro_racers_logic.dart';
import 'package:shella/services/audio_service.dart';

/// Visual-proof renders for ميكرو ريسرز (written to test/goldens/, not
/// comparison goldens). Timings below are controlled test delays.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => AudioService.mutedForTests = true);
  tearDown(() => AudioService.mutedForTests = false);
  final boundaryKey = GlobalKey();

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
    SharedPreferences.setMockInitialValues({'sound_enabled': false});
  });

  MicroRaceMatch m(WidgetTester t) =>
      (t.state(find.byType(MicroRacersGame)) as dynamic).debugMatch as MicroRaceMatch;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamilyFallback: const ['Noto Color Emoji']),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: RepaintBoundary(key: boundaryKey, child: const MicroRacersGame(randomSeed: 5)),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 400)));
    // advance fake time past the intro fade-ins (delays up to 400ms)
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 60));
    final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2.0));
    final byteData = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
    final bytes = byteData!.buffer.asUint8List();
    File('test/goldens/$name.png').writeAsBytesSync(bytes);
    expect(bytes.length, greaterThan(8000));
  }

  testWidgets('4 humans: intro -> pickers -> mid-race; lane tap cycles that car only', (tester) async {
    await open(tester);
    await capture(tester, 'micro_racers_intro');
    await tester.tap(find.text('ابدأ اللعبة 🚀'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
    await capture(tester, 'micro_racers_picker');
    await tester.tap(find.text('4 لاعبين'));
    await tester.pump(const Duration(milliseconds: 200));
    final match = m(tester);
    expect(match.seats, 4);
    expect(match.botSeats, isEmpty);
    // let the race run (controlled delay)
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await capture(tester, 'micro_racers_race');
    // lane tap: only seat 1's car cycles
    final laneBefore = [for (var s = 0; s < 4; s++) match.cars[s].lane];
    await tester.tap(find.byKey(const ValueKey('lane_tap_1')));
    await tester.pump(const Duration(milliseconds: 100));
    for (var s = 0; s < 4; s++) {
      if (s == 1) {
        expect(match.cars[s].lane, (laneBefore[s] + 1) % 3);
      } else {
        expect(match.cars[s].lane, laneBefore[s]);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('finish: a human crossing first sees the friends victory with their name', (tester) async {
    await open(tester);
    await tester.tap(find.text('ابدأ اللعبة 🚀'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 200));
    final match = m(tester);
    expect(match.seats, 2);
    // park seat 1 at the line, let seat 0 cruise through
    match.cars[1].dist = -100000; // sentinel keeps it from finishing... no: it must not advance
    match.cars[1].speed = 0;
    match.cars[1].dist = 0;
    match.cars[1].stallUntil = 9999; // frozen car, oil style
    match.cars[1].slowUntil = 9999;
    for (var i = 0; i < 400 && !match.over; i++) {
      match.step(1 / 30);
    }
    expect(match.over, isTrue);
    expect(match.winner, 0);
    await tester.pump(const Duration(milliseconds: 100));
    await capture(tester, 'micro_racers_finish');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
