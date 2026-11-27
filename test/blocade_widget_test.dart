import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/games/offline/blocade_game.dart';
import 'package:shella/services/settings_service.dart';
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

  Future<void> end(WidgetTester tester) async {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> pump(WidgetTester tester, double w, double h) async {
    tester.view.physicalSize = Size(w, h);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await SettingsService.init();
    await tester.pumpWidget(const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: BlocadeGameScreen(randomSeed: 3)));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 900));
  }

  for (final size in [const Size(412, 900), const Size(360, 640)]) {
    testWidgets('blocade 2P flow at ${size.width.toInt()}', (tester) async {
      await pump(tester, size.width, size.height);
      await tester.tap(find.text('ابدأ اللعبة 🚀'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('لاعبين ٢'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      final board = find.byKey(const ValueKey('blocade_board'));
      final tl = tester.getTopLeft(board);
      final s = tester.getSize(board).width / 9;
      // seat 0 at (8,4) moves up to (7,4)
      await tester.tapAt(tl + Offset(4.5 * s, 7.5 * s));
      await tester.pump();
      expect(find.text('دور لاعب 2').evaluate().isNotEmpty ||
          find.textContaining('دور').evaluate().isNotEmpty, true);
      // wall mode, preview, confirm
      await tester.tap(find.byKey(const ValueKey('mode_wall')));
      await tester.pump();
      await tester.tapAt(tl + Offset(4 * s + 3, 4 * s + 3));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('wall_confirm')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await end(tester);
    });
  }
}
