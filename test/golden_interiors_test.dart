import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/services/settings_service.dart';
import 'package:shella/theme/funky_theme.dart';
import 'package:shella/games/offline/most_likely_game.dart';
import 'package:shella/games/offline/taboo_game.dart';
import 'package:shella/games/offline/memory_game.dart';
import 'package:shella/games/offline/emoji_guess_game.dart';
import 'package:shella/games/offline/quiz_game.dart';
import 'package:shella/games/offline/who_am_i_game.dart';
import 'package:shella/games/offline/bus_complete_game.dart';

/// Golden interior renders: each game is driven past its intro and player
/// selection into actual gameplay, then screenshot-compared. Regenerate with:
///   flutter test test/golden_interiors_test.dart --update-goldens
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await SettingsService.init();
    // Seed three saved players so tests can select with taps instead of
    // typing (avoids a text-input font race under fake async).
    await SettingsService.savePlayersProfiles([
      {'name': 'أحمد', 'avatar': ''},
      {'name': 'منى', 'avatar': ''},
      {'name': 'كريم', 'avatar': ''},
    ]);
    for (final name in [
      'Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black'
    ]) {
      final bytes =
          await File('assets/fonts/Cairo-$name.ttf').readAsBytes();
      final loader = FontLoader('Cairo')
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
    final icons = await File(
      Platform.environment['HOME']! +
          '/sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytes();
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons)));
    await iconLoader.load();
  });

  Future<void> pumpGame(WidgetTester tester, Widget game) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: game,
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

  /// Taps the intro start button, selects the 3 seeded players, and starts.
  Future<void> intoGameplay(WidgetTester tester) async {
    await tester.tap(find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    for (final name in ['أحمد', 'منى', 'كريم']) {
      await tester.tap(find.text(name).first);
      await fixedPumps(tester, 3);
    }
    await tester.tap(find.text('بدء اللعبة'));
    await fixedPumps(tester);
  }

  testWidgets('taboo interior', (tester) async {
    await pumpGame(tester, const TabooGame());
    await intoGameplay(tester);
    await expectLater(
      find.byType(TabooGame),
      matchesGoldenFile('goldens/interior_taboo.png'),
    );
  });

  testWidgets('memory interior', (tester) async {
    await pumpGame(tester, const MemoryGame());
    await intoGameplay(tester);
    // Flip two cards for a lived-in board.
    final cards = find.text('❓');
    if (cards.evaluate().length >= 2) {
      await tester.tap(cards.at(2));
      await fixedPumps(tester, 2);
      await tester.tap(cards.at(7));
      await fixedPumps(tester, 2);
    }
    await expectLater(
      find.byType(MemoryGame),
      matchesGoldenFile('goldens/interior_memory.png'),
    );
  });

  testWidgets('emoji guess interior', (tester) async {
    await pumpGame(tester, const EmojiGuessGame());
    await intoGameplay(tester);
    await expectLater(
      find.byType(EmojiGuessGame),
      matchesGoldenFile('goldens/interior_emoji_guess.png'),
    );
  });

  testWidgets('quiz interior (existing game)', (tester) async {
    await pumpGame(tester, const QuizGame());
    await expectLater(
      find.byType(QuizGame),
      matchesGoldenFile('goldens/interior_quiz.png'),
    );
  });

  testWidgets('who am i interior (existing game)', (tester) async {
    await pumpGame(tester, const WhoAmIGame());
    await expectLater(
      find.byType(WhoAmIGame),
      matchesGoldenFile('goldens/interior_who_am_i.png'),
    );
  });

  testWidgets('bus complete interior (existing game)', (tester) async {
    await pumpGame(tester, const BusCompleteGame());
    await expectLater(
      find.byType(BusCompleteGame),
      matchesGoldenFile('goldens/interior_bus_complete.png'),
    );
  });
  testWidgets('most likely interior', (tester) async {
    await pumpGame(tester, const MostLikelyGame());
    await intoGameplay(tester);
    // Reveal the voting grid.
    final countBtn = find.text('عدّوا 3-2-1 وأشيروا! 🫵');
    if (countBtn.evaluate().isNotEmpty) {
      await tester.tap(countBtn);
      await fixedPumps(tester);
    }
    await expectLater(
      find.byType(MostLikelyGame),
      matchesGoldenFile('goldens/interior_most_likely.png'),
    );
  });

}
