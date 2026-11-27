import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/games/offline/goal_rush_game.dart';
import 'package:shella/games/offline/goal_rush_logic.dart';
import 'package:shella/services/audio_service.dart';

/// Visual-proof renders for جري الجون (written to test/goldens/, not
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

  GoalRushMatch m(WidgetTester t) =>
      (t.state(find.byType(GoalRushGame)) as dynamic).debugMatch as GoalRushMatch;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamilyFallback: const ['Noto Color Emoji']),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: RepaintBoundary(key: boundaryKey, child: const GoalRushGame(randomSeed: 11)),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 400)));
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

  testWidgets('2 humans: holding the pad runs that runner only; release spins', (tester) async {
    await open(tester);
    await capture(tester, 'goal_rush_intro');
    await tester.tap(find.text('ابدأ اللعبة 🚀'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 200));
    final match = m(tester);
    expect(match.seats, 2);
    expect(match.botSeats, isEmpty);

    final pad0 = find.byKey(const ValueKey('rush_pad_0'));
    expect(pad0, findsOneWidget);
    final x0 = match.runners[0].x, y0 = match.runners[0].y;
    final h0 = match.runners[0].heading;
    final g = await tester.startGesture(tester.getCenter(pad0));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(match.runners[0].holding, isTrue);
    expect(
        (match.runners[0].x - x0).abs() + (match.runners[0].y - y0).abs(),
        greaterThan(2),
        reason: 'runner moves while held');
    expect(match.runners[0].heading, h0, reason: 'no turn while held');
    expect(match.runners[1].holding, isFalse, reason: 'other seat untouched');
    await capture(tester, 'goal_rush_play');
    await g.up();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(match.runners[0].holding, isFalse);
    expect(match.runners[0].heading, isNot(h0), reason: 'spins after release');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('3 goals end the match with the friends victory', (tester) async {
    await open(tester);
    await tester.tap(find.text('ابدأ اللعبة 🚀'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 200));
    final match = m(tester);
    for (var g = 0; g < 3; g++) {
      match.runners[0].x = 50;
      match.runners[0].y = 20;
      match.ballX = 50;
      match.ballY = 12;
      match.ballVx = 0;
      match.ballVy = -30;
      match.lastToucher = 0;
      for (var t = 0.0; t < 1.5 && !match.over; t += 1 / 120) {
        match.step(1 / 120);
      }
    }
    expect(match.winner, 0);
    await tester.pump(const Duration(milliseconds: 200));
    await capture(tester, 'goal_rush_win');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
