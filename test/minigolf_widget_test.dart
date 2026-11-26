import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/games/offline/minigolf_game.dart';
import 'package:shella/services/audio_service.dart';
import 'package:shella/services/settings_service.dart';

void main() {
  setUp(() => AudioService.mutedForTests = true);
  tearDown(() => AudioService.mutedForTests = false);
  TestWidgetsFlutterBinding.ensureInitialized();
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

  Future<void> end(WidgetTester tester) async {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> pumpGame(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await SettingsService.init();
    await tester.pumpWidget(const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MiniGolfGameScreen()));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 900));
  }

  Future<void> toBanner(WidgetTester tester) async {
    await pumpGame(tester);
    await tester.tap(find.text('ابدأ اللعبة 🚀'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('intro starts to the player picker', (tester) async {
    await pumpGame(tester);
    await tester.tap(find.text('ابدأ اللعبة 🚀'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('كام لاعب؟ ⛳'), findsOneWidget);
    await end(tester);
  });

  testWidgets('banner names the hole and the seat', (tester) async {
    await toBanner(tester);
    expect(find.text('حفرة 1 من 3'), findsOneWidget);
    expect(find.text('دور لاعب 1'), findsOneWidget);
    await end(tester);
  });

  testWidgets('course renders with cup, flag and ball; golden', (tester) async {
    await toBanner(tester);
    await tester.tap(find.text('دوس للبدء 👆'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('لاعب 1: 0 ضربات'), findsOneWidget);
    await expectLater(find.byType(MiniGolfGameScreen),
        matchesGoldenFile('goldens/minigolf_course.png'));
    await end(tester);
  });

  testWidgets('a drag from the ball putts it and counts a stroke',
      (tester) async {
    await toBanner(tester);
    await tester.tap(find.text('دوس للبدء 👆'));
    await tester.pump(const Duration(milliseconds: 300));
    final s = tester.state(find.byType(MiniGolfGameScreen)) as dynamic;
    final scale = s.debugScale as double;
    final hole = s.debugHole;
    // Ball at (180,460) logical; drag downward (slingshot up) ~120px logical.
    final rect = tester.getRect(find.byType(CustomPaint).last);
    final ballAt = rect.topLeft + Offset(180 * scale, 460 * scale);
    await tester.dragFrom(ballAt, Offset(0, 120 * scale));
    await tester.pump(const Duration(milliseconds: 300));
    expect(hole.strokes, 1);
    // Let the ball stop.
    for (var i = 0; i < 80 && !(hole.resting || hole.sunk); i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(hole.resting || hole.sunk, isTrue);
    await end(tester);
  });

  testWidgets('bots fill seats when asked', (tester) async {
    await pumpGame(tester);
    await tester.tap(find.text('ابدأ اللعبة 🚀'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('لاعب واحد'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('اه 🤖'));
    await tester.pump(const Duration(milliseconds: 300));
    final s = tester.state(find.byType(MiniGolfGameScreen)) as dynamic;
    expect(s.debugSeatCount, 4);
    expect(s.debugBots.length, 3);
    await end(tester);
  });
}
