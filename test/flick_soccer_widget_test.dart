import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/games/offline/flick_soccer_game.dart';
import 'package:shella/games/offline/flick_soccer_logic.dart';

/// Visual-proof renders for فليك الشلة (written to test/goldens/, not
/// comparison goldens). Timings below are controlled test delays.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  FlickSoccerMatch m(WidgetTester t) =>
      (t.state(find.byType(FlickSoccerGame)) as dynamic).debugMatch as FlickSoccerMatch;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamilyFallback: const ['Noto Color Emoji']),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: RepaintBoundary(key: boundaryKey, child: const FlickSoccerGame(randomSeed: 9)),
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

  testWidgets('2 humans: drag on your disc flicks it; only the current seat can pull', (tester) async {
    await open(tester);
    await capture(tester, 'flick_soccer_intro');
    await tester.tap(find.text('ابدأ اللعبة 🚀'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 200));
    final match = m(tester);
    expect(match.seats, 2);
    expect(match.botSeats, isEmpty);
    expect(match.currentSeat, 0);

    // drag from seat 0's disc (bottom) downward -> flicks it upward
    final field = find.byKey(const ValueKey('flick_field'));
    final fieldBox = tester.getRect(field);
    final scale = fieldBox.width / FlickSoccerMatch.fieldW;
    final disc0 = fieldBox.topLeft +
        Offset(match.discs[0].x * scale, match.discs[0].y * scale);
    final g = await tester.startGesture(disc0);
    await tester.pump(const Duration(milliseconds: 100));
    await g.moveBy(const Offset(0, 60));
    await tester.pump(const Duration(milliseconds: 100));
    await capture(tester, 'flick_soccer_pull');
    await g.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(match.discs[0].moving, isTrue);
    // let physics run (controlled delay), then everything settles and the turn passes
    for (var i = 0; i < 150 && !match.settled; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(match.settled, isTrue);
    expect(match.currentSeat, 1);
    await capture(tester, 'flick_soccer_play');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('a goal on the board then the match win shows the friends victory', (tester) async {
    await open(tester);
    await tester.tap(find.text('ابدأ اللعبة 🚀'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 200));
    final match = m(tester);
    // score 3 goals for seat 0 through the real physics
    for (var g = 0; g < 3; g++) {
      if (match.currentSeat != 0) {
        match.flick(match.currentSeat, 6, 0);
        while (!match.settled && !match.over) {
          match.step();
        }
      }
      match.discs[1].x = 20;
      match.discs[1].y = 22;
      match.ball.x = 50;
      match.ball.y = 50;
      match.ball.vx = match.ball.vy = 0;
      match.discs[0].x = 50;
      match.discs[0].y = 58;
      match.flick(0, 0, 22);
      while (!match.settled && !match.over) {
        match.step();
      }
    }
    expect(match.winner, 0);
    await tester.pump(const Duration(milliseconds: 200));
    await capture(tester, 'flick_soccer_win');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
