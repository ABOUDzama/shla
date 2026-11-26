import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/games/offline/croc_game.dart';
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
        home: CrocGameScreen(randomSeed: 3)));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 900));
  }

  Future<void> toPlaying(WidgetTester tester) async {
    await pumpGame(tester);
    await tester.tap(find.text('ابدأ اللعبة 🚀'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('intro starts to the player picker', (tester) async {
    await pumpGame(tester);
    await tester.tap(find.text('ابدأ اللعبة 🚀'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('كام لاعب؟ 🐊'), findsOneWidget);
    await end(tester);
  });

  testWidgets('2 humans, no bots: croc head with 10 tappable teeth', (tester) async {
    await toPlaying(tester);
    expect(find.byKey(const ValueKey('tooth_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('tooth_9')), findsOneWidget);
    expect(find.byKey(const ValueKey('tooth_10')), findsNothing);
    await expectLater(find.byType(CrocGameScreen),
        matchesGoldenFile('goldens/croc_play.png'));
    await end(tester);
  });

  testWidgets('tapping a tooth pulls it and passes the turn', (tester) async {
    await toPlaying(tester);
    final g0 = (tester.state(find.byType(CrocGameScreen)) as dynamic).debugGame;
    final before = g0.currentPlayer;
    final sore = g0.soreTooth;
    // Tap a tooth that is not the sore one (guaranteed safe).
    final safe = (sore + 3) % 10 == sore ? (sore + 4) % 10 : (sore + 3) % 10;
    await tester.tap(find.byKey(ValueKey('tooth_$safe')));
    await tester.pump(const Duration(milliseconds: 400));
    final g = (tester.state(find.byType(CrocGameScreen)) as dynamic).debugGame;
    expect(g.currentPlayer, isNot(before));
    expect(g.standing.contains(safe), isFalse);
    await end(tester);
  });

  testWidgets('bots fill the seats and play on their own', (tester) async {
    await pumpGame(tester);
    await tester.tap(find.text('ابدأ اللعبة 🚀'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('لاعب واحد'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('اه 🤖'));
    await tester.pump(const Duration(milliseconds: 400));
    final g = (tester.state(find.byType(CrocGameScreen)) as dynamic).debugGame;
    expect(g.playerCount, 4);
    expect(g.isBot(3), isTrue);
    expect(g.isBot(0), isFalse);
    await end(tester);
  });
}
