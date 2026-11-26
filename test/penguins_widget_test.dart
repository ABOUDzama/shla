import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/games/offline/penguins_game.dart';
import 'package:shella/services/settings_service.dart';

void main() {
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
        home: PenguinsGameScreen()));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 900));
  }

  Future<void> toArena(WidgetTester tester) async {
    await pumpGame(tester);
    await tester.tap(find.text('ابدأ اللعبة 🚀'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('intro starts to the player picker', (tester) async {
    await pumpGame(tester);
    await tester.tap(find.text('ابدأ اللعبة 🚀'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('كام لاعب؟ 🐧'), findsOneWidget);
    await end(tester);
  });

  testWidgets('2P duel arena renders both penguins and the berg; golden',
      (tester) async {
    await toArena(tester);
    expect(find.text('دور لاعب 1'), findsOneWidget);
    await expectLater(find.byType(PenguinsGameScreen),
        matchesGoldenFile('goldens/penguins_arena.png'));
    await end(tester);
  });

  testWidgets('a drag from the penguin launches a snowball', (tester) async {
    await toArena(tester);
    final rect = tester.getRect(find.byType(CustomPaint).last);
    // Penguin 1 at world (40, 224); scale = rect.width / 480.
    final s = rect.width / 480;
    final penguinAt = rect.topLeft + Offset(40 * s, 224 * s);
    // Pull down-left (slingshot up-right).
    await tester.dragFrom(penguinAt, Offset(-70 * s, 70 * s));
    await tester.pump(const Duration(milliseconds: 200));
    final st = tester.state(find.byType(PenguinsGameScreen)) as dynamic;
    expect(st.debugFlying, isTrue);
    await end(tester);
  });

  testWidgets('1P vs bot offers bot and dummy choices', (tester) async {
    await pumpGame(tester);
    await tester.tap(find.text('ابدأ اللعبة 🚀'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('لاعب واحد'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('بوت يرمي كمان 🤖'), findsOneWidget);
    expect(find.text('دمية تمرين 🎯'), findsOneWidget);
    await end(tester);
  });
}
