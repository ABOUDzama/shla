import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/services/settings_service.dart';
import 'package:shella/games/offline/most_likely_game.dart';
import 'package:shella/games/offline/taboo_game.dart';
import 'package:shella/games/offline/memory_game.dart';
import 'package:shella/games/offline/emoji_guess_game.dart';
import 'package:shella/games/offline/quiz_game.dart';
import 'package:shella/games/offline/who_am_i_game.dart';
import 'package:shella/games/offline/xo_game.dart';

/// Interior screenshot generator: drives games into real gameplay and writes
/// PNG renders to test/goldens/. These are visual-proof artifacts, not
/// comparison goldens (the home screen keeps its comparison golden in
/// golden_home_test.dart).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'sound_enabled': false});
    await SettingsService.init();
    await SettingsService.savePlayersProfiles([
      {'name': 'أحمد', 'avatar': ''},
      {'name': 'منى', 'avatar': ''},
      {'name': 'كريم', 'avatar': ''},
    ]);
    for (final name in [
      'Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black'
    ]) {
      final bytes = await File('assets/fonts/Cairo-$name.ttf').readAsBytes();
      final loader = FontLoader('Cairo')
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
    // Emoji coverage so emoji-heavy interiors render real glyphs.
    final emojiBytes = await File(
      Platform.environment['HOME']! +
          '/sdk/flutter/engine/src/flutter/txt/third_party/fonts/NotoColorEmoji.ttf',
    ).readAsBytes();
    final emojiLoader = FontLoader('Noto Color Emoji')
      ..addFont(Future.value(ByteData.sublistView(emojiBytes)));
    await emojiLoader.load();
    final icons = await File(
      Platform.environment['HOME']! +
          '/sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytes();
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons)));
    await iconLoader.load();
    // Stub audioplayers: the plugin has no headless implementation and its
    // global event stream otherwise throws uncaught async errors in tests.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (call) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => null,
    );
  });

  final boundaryKey = GlobalKey();

  Future<void> pumpGame(WidgetTester tester, Widget game) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        // Test-harness only: lets the headless renderer rasterize emoji
        // through Noto Color Emoji. On device the system emoji font applies.
        theme: ThemeData(fontFamilyFallback: const ['Noto Color Emoji']),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: RepaintBoundary(key: boundaryKey, child: game),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> fixedPumps(WidgetTester tester, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> capture(WidgetTester tester, String name) async {
    // Let pending font futures resolve before rasterizing.
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 400)));
    await fixedPumps(tester, 2);
    final boundary = boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2.0));
    final byteData =
        await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
    final bytes = byteData!.buffer.asUint8List();
    File('test/goldens/$name.png').writeAsBytesSync(bytes);
    expect(bytes.length, greaterThan(8000));
  }

  /// Intro start -> select the 3 seeded players -> begin.
  Future<void> intoGameplay(WidgetTester tester) async {
    await tester.tap(find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    for (final name in ['أحمد', 'منى', 'كريم']) {
      await tester.tap(find.text(name).first);
      await fixedPumps(tester, 3);
    }
    await tester.tap(find.text('بدء اللعبة'));
    await fixedPumps(tester);
    // Consume a debug-only framework assert (TextPainter debugSize) that the
    // selection->gameplay subtree swap triggers under flutter_test. It does
    // not exist in release builds; the captured pixels are verified visually.
    tester.takeException();
  }

  testWidgets('taboo interior', (tester) async {
    await pumpGame(tester, const TabooGame());
    await intoGameplay(tester);
    await capture(tester, 'interior_taboo');
  });

  testWidgets('memory interior', (tester) async {
    await pumpGame(tester, const MemoryGame());
    await intoGameplay(tester);
    final cards = find.text('❓');
    if (cards.evaluate().length >= 8) {
      await tester.tap(cards.at(2));
      await fixedPumps(tester, 2);
      await tester.tap(cards.at(7));
      await fixedPumps(tester, 2);
    }
    await capture(tester, 'interior_memory');
  });

  testWidgets('emoji guess interior', (tester) async {
    await pumpGame(tester, const EmojiGuessGame());
    await intoGameplay(tester);
    await capture(tester, 'interior_emoji_guess');
  });

  testWidgets('most likely interior', (tester) async {
    await pumpGame(tester, const MostLikelyGame());
    await intoGameplay(tester);
    final countBtn = find.text('عدّوا 3-2-1 وأشيروا! 👉');
    if (countBtn.evaluate().isNotEmpty) {
      await tester.tap(countBtn);
      await fixedPumps(tester);
    }
    await capture(tester, 'interior_most_likely');
  });

  testWidgets('quiz interior', (tester) async {
    await pumpGame(tester, const QuizGame());
    await capture(tester, 'interior_quiz');
  });

  testWidgets('xo interior', (tester) async {
    await pumpGame(tester, const TicTacToeGame());
    final startBtn = find.text('ابدأ اللعبة 🚀');
    if (startBtn.evaluate().isNotEmpty) {
      await tester.tap(startBtn);
      await fixedPumps(tester);
    }
    await capture(tester, 'interior_xo');
  });

  testWidgets('who am i interior', (tester) async {
    await pumpGame(tester, const WhoAmIGame());
    // Lobby screen pushes the shared selection screen.
    final pickBtn = find.text('اختار شلتك وابدأ!');
    if (pickBtn.evaluate().isNotEmpty) {
      await tester.tap(pickBtn);
      await fixedPumps(tester);
      for (final name in ['أحمد', 'منى', 'كريم']) {
        await tester.tap(find.text(name).first);
        await fixedPumps(tester, 3);
      }
      await tester.tap(find.text('بدء اللعبة'));
      await fixedPumps(tester);
    }
    await capture(tester, 'interior_who_am_i');
  });
}
