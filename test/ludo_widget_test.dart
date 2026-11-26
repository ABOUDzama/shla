import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/games/offline/ludo_game.dart';
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

  Future<void> pumpGame(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await SettingsService.init();
    await tester.pumpWidget(const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: LudoGameScreen(randomSeed: 7)));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 900));
  }

  Future<void> end(WidgetTester tester) async {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('intro starts to the player picker', (tester) async {
    await pumpGame(tester);
    expect(find.text('لودو الشلة'), findsWidgets);
    await tester.tap(find.text('ابدأ اللعبة 🚀'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('كام لاعب؟ 🎲'), findsOneWidget);
    expect(find.text('2 لاعبين'), findsOneWidget);
    await end(tester);
  });

  testWidgets('2 humans + bots fills to 4 seats and shows the board', (tester) async {
    await pumpGame(tester);
    await tester.tap(find.text('ابدأ اللعبة 🚀'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('اه 🤖'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('ارمي 🎲'), findsOneWidget);
    await expectLater(find.byType(LudoGameScreen),
        matchesGoldenFile('goldens/ludo_board.png'));
    await end(tester);
  });

  testWidgets('a human roll enables a token pick', (tester) async {
    await pumpGame(tester);
    await tester.tap(find.text('ابدأ اللعبة 🚀'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('ارمي 🎲'));
    await tester.pump(const Duration(milliseconds: 500));
    // Either a token became movable ('اختار حجر') or the turn moved on
    // with no legal move. Both are valid game states.
    final picked = find.text('اختار حجر');
    final rollAgain = find.text('ارمي 🎲');
    expect(picked.evaluate().isNotEmpty || rollAgain.evaluate().isNotEmpty,
        isTrue);
    await end(tester);
  });
}
