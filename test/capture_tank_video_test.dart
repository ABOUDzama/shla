import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shella/games/offline/tank_battle_game.dart';

/// Automated-harness UI capture for the rebuilt Tank Battle game.
///
/// Real gestures (hold-to-steer, release-to-fire) are driven through the
/// widget tester; frames are read from the live widget tree through a
/// RepaintBoundary and written as PNGs for ffmpeg assembly. This is NOT a
/// device gameplay recording — it is a scripted, deterministic capture of
/// the actual running UI, used to show input -> state -> win.
///
/// Only runs when CAPTURE_VIDEO=1 is set, so the normal suite stays fast.

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
  final enabled = Platform.environment['CAPTURE_VIDEO'] == '1';

  testWidgets('capture scripted match frames', (tester) async {
    final outDir = Directory('build/video_frames');
    if (outDir.existsSync()) outDir.deleteSync(recursive: true);
    outDir.createSync(recursive: true);

    final boundaryKey = GlobalKey();
    var frame = 0;

    Future<void> snapFrame() async {
      final boundary = boundaryKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 0.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${outDir.path}/frame_${frame.toString().padLeft(4, '0')}.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
      frame++;
    }

    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await warmGoogleFonts(tester);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamilyFallback: const ['Noto Color Emoji']),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: RepaintBoundary(
          key: boundaryKey,
          child: const TankBattleGame(randomSeed: 2026),
        ),
      ),
    ));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await tester.pump();

    // intro (2 frames)
    await snapFrame();
    await snapFrame();
    await tester.tap(find.textContaining('ابدأ اللعبة'));
    await tester.pump();
    await snapFrame(); // player picker
    await tester.tap(find.text('4 لاعبين'));
    await tester.pump();
    await snapFrame(); // opening arena state

    // scripted play: deterministic per-player hold/release cadence.
    // Pattern repeats every 12 frames (200ms each => 2.4s):
    // player p holds frames [p*2, p*2+3] then releases (fires).
    final held = <int, TestGesture>{};
    for (var f = 0; f < 240; f++) {
      final phase = f % 12;
      for (var p = 1; p <= 4; p++) {
        final startAt = (p - 1) * 3;
        if (phase == startAt && !held.containsKey(p)) {
          final finder = find.text('لاعب $p 🎯');
          if (finder.evaluate().isNotEmpty) {
            held[p] = await tester.startGesture(tester.getCenter(finder));
          }
        } else if (phase == startAt + 2 && held.containsKey(p)) {
          await held.remove(p)!.up();
        }
      }
      await tester.pump(const Duration(milliseconds: 200));
      await snapFrame();
      // stop ~1.5s after the round ends so the win screen shows
      if (find.text('العبوا تاني 🎯').evaluate().isNotEmpty) {
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 200));
          await snapFrame();
        }
        break;
      }
    }
    // guarantee a resolved ending for the video
    if (find.text('العبوا تاني 🎯').evaluate().isEmpty) {
      (tester.state(find.byType(TankBattleGame)) as dynamic).debugForceWin(0);
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        await snapFrame();
      }
    }
    // marker file with frame count for ffmpeg
    File('${outDir.path}/COUNT').writeAsStringSync('$frame');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }, skip: !enabled, timeout: const Timeout(Duration(minutes: 10)));
}
