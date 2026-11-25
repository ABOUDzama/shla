import 'dart:math';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/services/settings_service.dart';
import 'package:shella/games/offline/memory_game.dart';
import 'package:shella/games/offline/password_game.dart';
import 'package:shella/games/offline/spy_game.dart';
import 'package:shella/games/offline/undercover_game.dart';
import 'package:shella/games/offline/mafia_game.dart';
import 'package:shella/theme/funky_theme.dart';
import 'package:shella/games/offline/proverb_game.dart';
import 'package:shella/games/offline/who_said_game.dart';
import 'package:shella/games/offline/most_likely_game.dart';
import 'package:shella/games/offline/taboo_game.dart';
import 'package:shella/games/offline/emoji_guess_game.dart';
import 'package:shella/games/offline/who_am_i_game.dart';
import 'package:shella/games/offline/would_rather_game.dart';
import 'package:shella/games/offline/never_have_i_game.dart';
import 'package:shella/games/offline/word_story_game.dart';
import 'package:shella/games/offline/code_names_game.dart';

/// Interaction/state-transition tests: play each of the 4 new games through
/// real taps and assert real state changes (round counters, turn rotation,
/// score awards, timer restart, winner screens). Uses the same font/mock
/// harness as small_screen_test.
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
      {'name': 'سارة', 'avatar': ''},
      {'name': 'عمر', 'avatar': ''},
      {'name': 'ليلى', 'avatar': ''},
      {'name': 'حسن', 'avatar': ''},
      {'name': 'دينا', 'avatar': ''},
    ]);
    for (final name in [
      'Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black'
    ]) {
      final bytes = await File('assets/fonts/Cairo-$name.ttf').readAsBytes();
      final loader = FontLoader('Cairo')
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
    final emojiBytes =
        await File('test/fonts_NotoColorEmoji.ttf').readAsBytes();
    final emojiLoader = FontLoader('Noto Color Emoji')
      ..addFont(Future.value(ByteData.sublistView(emojiBytes)));
    await emojiLoader.load();
    final pmBytes =
        await File('test/fonts_PermanentMarker-Regular.ttf').readAsBytes();
    final pmLoader = FontLoader('Permanent Marker')
      ..addFont(Future.value(ByteData.sublistView(pmBytes)));
    await pmLoader.load();
    final icons = await File(
      Platform.environment['HOME']! +
          '/sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytes();
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons)));
    await iconLoader.load();
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
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (call) async => <String>['none'],
    );
  });

  Future<void> pumpGame(WidgetTester tester, Widget game) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamilyFallback: const ['Noto Color Emoji']),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: game,
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> flushFontCallbacks(WidgetTester tester) async {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await tester.pump();
  }

  Future<void> fixedPumps(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final f = find.text(text);
    expect(f, findsWidgets, reason: 'expected tappable text: $text');
    await tester.ensureVisible(f.first);
    await fixedPumps(tester, 2);
    await tester.tap(f.first, warnIfMissed: false);
    await fixedPumps(tester);
  }

  Future<void> tapContaining(WidgetTester tester, String fragment) async {
    final f = find.textContaining(fragment);
    expect(f, findsWidgets, reason: 'expected tappable text: $fragment');
    await tester.ensureVisible(f.first);
    await fixedPumps(tester, 2);
    await tester.tap(f.first, warnIfMissed: false);
    await fixedPumps(tester);
  }

  Future<void> untilFound(WidgetTester tester, String text,
      [int tries = 12]) async {
    for (var i = 0; i < tries; i++) {
      if (find.text(text).evaluate().isNotEmpty) return;
      await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text(text), findsOneWidget,
        reason: 'never appeared: $text');
  }

  Future<void> pickPlayersAndStart(WidgetTester tester,
      [List<String> names = const ['أحمد', 'منى']]) async {
    for (final name in names) {
      await tapText(tester, name);
    }
    await tapText(tester, 'بدء اللعبة');
    tester.takeException(); // known harness-only debugSize assert
    await flushFontCallbacks(tester);
  }

  group('most likely: full 12-round match', () {
    testWidgets('scoring, round advance, winner screen, replay', (tester) async {
      await pumpGame(tester, const MostLikelyGame());
      await flushFontCallbacks(tester);
      await tapText(tester, 'ابدأ اللعبة 🚀');
      await pickPlayersAndStart(tester);

      expect(find.text('الجولة 1 من 12'), findsOneWidget);
      for (var round = 1; round <= 12; round++) {
        await tapText(tester, 'عدّوا 3-2-1 وأشيروا! 👉');
        expect(find.text('مين اختاروه؟ 👀'), findsOneWidget);
        // Always vote for أحمد; his pre-pick score equals rounds already won.
        await tapText(tester, 'أحمد (${round - 1})');
        if (round < 12) {
          expect(find.text('الجولة ${round + 1} من 12'), findsOneWidget);
        }
      }

      expect(find.text('المتهم الأول في الشلة:'), findsOneWidget);
      expect(find.text('أحمد — 12 نقطة'), findsOneWidget);
      expect(find.text('منى — 0 نقطة'), findsOneWidget);

      await tapText(tester, 'العب تاني 🔄');
      expect(find.text('ابدأ اللعبة 🚀'), findsOneWidget);
      await flushFontCallbacks(tester);
    });
  });

  group('emoji guess: award vs no-award paths', () {
    testWidgets('award increments score, reveal-only does not, 10 rounds end',
        (tester) async {
      await pumpGame(tester, const EmojiGuessGame());
      await flushFontCallbacks(tester);
      await tapText(tester, 'ابدأ اللعبة 🚀');
      await pickPlayersAndStart(tester);

      expect(find.text('الجولة 1 من 10'), findsOneWidget);
      // Round 1: أحمد guesses correctly.
      await tapText(tester, 'أحمد (0)');
      expect(find.text('الكارت اللي بعده ⏭️'), findsOneWidget);
      await tapText(tester, 'الكارت اللي بعده ⏭️');
      expect(find.text('الجولة 2 من 10'), findsOneWidget);
      expect(find.text('أحمد (1)'), findsOneWidget);

      // Rounds 2-10: nobody guesses; reveal then advance.
      for (var round = 2; round <= 10; round++) {
        expect(find.text('الجولة $round من 10'), findsOneWidget);
        expect(find.text('منى (0)'), findsOneWidget);
        await tapText(tester, 'محدش عرف 😅 اعرض الإجابة');
        expect(find.text('الكارت اللي بعده ⏭️'), findsOneWidget);
        await tapText(tester, 'الكارت اللي بعده ⏭️');
      }

      expect(find.text('عبقري الإيموجي: أحمد'), findsOneWidget);
      expect(find.text('أحمد — 1 نقطة'), findsOneWidget);
      await flushFontCallbacks(tester);
    });
  });

  group('taboo: timer-driven turns', () {
    testWidgets('turn timer runs out, rotates describer, restarts, ends game',
        (tester) async {
      await pumpGame(tester, const TabooGame());
      await flushFontCallbacks(tester);
      await tapText(tester, 'ابدأ اللعبة 🚀');
      await pickPlayersAndStart(tester);

      expect(find.text('الواصف: أحمد'), findsOneWidget);
      expect(find.textContaining('⏱'), findsOneWidget);
      await tapText(tester, 'خمّنوها! +1 ✅'); // أحمد: 1
      await tapText(tester, 'تخطي ⏭️');

      // Pumps 1s at a time until [target] is on screen (turn ended), then
      // asserts the clock restarted above zero for the next describer.
      Future<void> runOutTimerUntil(String target) async {
        var found = false;
        for (var i = 0; i < 70; i++) {
          await tester.pump(const Duration(seconds: 1));
          if (find.text(target).evaluate().isNotEmpty) {
            found = true;
            break;
          }
        }
        expect(found, isTrue, reason: 'turn never ended, waiting for: $target');
        await fixedPumps(tester, 2);
        final timerText = tester
            .widgetList<Text>(find.textContaining('⏱'))
            .map((t) => t.data ?? '')
            .join(' ');
        final seconds = int.tryParse(
            RegExp(r'⏱ (\d+)').firstMatch(timerText)?.group(1) ?? '0');
        expect(seconds, greaterThan(0),
            reason: 'timer dead after turn end: "$timerText"');
      }

      // Turn 1 (أحمد) times out -> منى, timer must restart (regression:
      // _endTurn used to leave the clock dead at 0 for every later turn).
      await runOutTimerUntil('الواصف: منى');

      // Turn 2 (منى): two correct guesses.
      await tapText(tester, 'خمّنوها! +1 ✅');
      await tapText(tester, 'خمّنوها! +1 ✅'); // منى: 2
      await runOutTimerUntil('الواصف: أحمد');

      // Turn 3 (أحمد) times out -> منى.
      await runOutTimerUntil('الواصف: منى');

      // Turn 4 (منى) times out -> 4 turns played = 2 players x 2 -> game over.
      var ended = false;
      for (var i = 0; i < 70; i++) {
        await tester.pump(const Duration(seconds: 1));
        if (find.text('أحسن واصف: منى').evaluate().isNotEmpty) {
          ended = true;
          break;
        }
      }
      expect(ended, isTrue, reason: 'game never reached winner screen');
      await fixedPumps(tester, 2);
      expect(find.text('أحسن واصف: منى'), findsOneWidget);
      expect(find.text('منى — 2 نقطة'), findsOneWidget);
      expect(find.text('أحمد — 1 نقطة'), findsOneWidget);
      await flushFontCallbacks(tester);
    });
  });

  group('memory: board scales with squad size', () {
    List<String> debugBoardOf(WidgetTester tester) =>
        (tester.state(find.byType(MemoryGame)) as dynamic).debugBoard
            as List<String>;
    List<bool> debugRevealedOf(WidgetTester tester) =>
        (tester.state(find.byType(MemoryGame)) as dynamic).debugRevealed
            as List<bool>;

    Future<void> intoMemory(WidgetTester tester, List<String> names) async {
      // Tall surface so GridView builds every card (lazy builder).
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await pumpGame(tester, const MemoryGame());
      await flushFontCallbacks(tester);
      await tapText(tester, 'ابدأ اللعبة 🚀');
      await pickPlayersAndStart(tester, names);
    }

    testWidgets('solo: 16 cards, match scores, mismatch flips back',
        (tester) async {
      await intoMemory(tester, ['أحمد']);
      expect(debugBoardOf(tester).length, 16);

      final cells = find.descendant(
          of: find.byType(GridView), matching: find.byType(GestureDetector));
      expect(cells, findsNWidgets(16));

      // Find a matching pair from game state and flip it: score +1.
      final board = List<String>.from(debugBoardOf(tester));
      final first = 0;
      final second = board.indexOf(board[first], 1);
      expect(second, greaterThan(0), reason: 'no pair for first card');
      await tester.tap(cells.at(first), warnIfMissed: false);
      await fixedPumps(tester, 2);
      await tester.tap(cells.at(second), warnIfMissed: false);
      await fixedPumps(tester, 2);
      expect(find.textContaining('أحمد: 1'), findsOneWidget);

      // Flip two non-matching cards: they flip back after the timer.
      final remaining = <int>[
        for (var i = 0; i < board.length; i++)
          if (i != first && i != second) i
      ];
      final a = remaining.first;
      final b = remaining.firstWhere((i) => board[i] != board[a]);
      await tester.tap(cells.at(a), warnIfMissed: false);
      await fixedPumps(tester, 2);
      await tester.tap(cells.at(b), warnIfMissed: false);
      await fixedPumps(tester, 2);
      expect(debugRevealedOf(tester)[a], isTrue);
      await tester.pump(const Duration(seconds: 1));
      await fixedPumps(tester, 2);
      expect(debugRevealedOf(tester)[a], isFalse);
      expect(debugRevealedOf(tester)[b], isFalse);
      await flushFontCallbacks(tester);
    });

    testWidgets('three players: 24 cards (4x6)', (tester) async {
      await intoMemory(tester, ['أحمد', 'منى', 'كريم']);
      expect(debugBoardOf(tester).length, 24);
      final cells = find.descendant(
          of: find.byType(GridView), matching: find.byType(GestureDetector));
      expect(cells, findsNWidgets(24));

      // Mismatch passes the turn to the next player.
      final board = List<String>.from(debugBoardOf(tester));
      final a = 0;
      final b = board.indexWhere((e) => e != board[a], 1);
      final cells2 = find.descendant(
          of: find.byType(GridView), matching: find.byType(GestureDetector));
      await tester.tap(cells2.at(a), warnIfMissed: false);
      await fixedPumps(tester, 2);
      await tester.tap(cells2.at(b), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 1));
      await fixedPumps(tester, 2);
      expect(find.text('دور: منى'), findsOneWidget);
      await flushFontCallbacks(tester);
    });

    testWidgets('six players: 30 cards (5x6)', (tester) async {
      await intoMemory(
          tester, ['أحمد', 'منى', 'كريم', 'سارة', 'عمر', 'ليلى']);
      expect(debugBoardOf(tester).length, 30);
      final cells = find.descendant(
          of: find.byType(GridView), matching: find.byType(GestureDetector));
      expect(cells, findsNWidgets(30));
      await flushFontCallbacks(tester);
    });

    testWidgets('eight players: 36 cards (6x6), all rendered, tappable size',
        (tester) async {
      await intoMemory(
        tester,
        ['أحمد', 'منى', 'كريم', 'سارة', 'عمر', 'ليلى', 'حسن', 'دينا'],
      );
      expect(debugBoardOf(tester).length, 36);
      final cells = find.descendant(
          of: find.byType(GridView), matching: find.byType(GestureDetector));
      // Every card must be laid out (non-scrollable grid clips otherwise)
      // and each cell stays a usable tap target in LOGICAL pixels.
      expect(cells, findsNWidgets(36));
      final size = tester.getSize(cells.first);
      expect(size.width, greaterThanOrEqualTo(48),
          reason: 'cell too narrow: $size');
      expect(size.height, greaterThanOrEqualTo(48),
          reason: 'cell too short: $size');
      await flushFontCallbacks(tester);
    });

    testWidgets('phone-sized surface: 24-card board fits without clipping',
        (tester) async {
      // 360x640 logical: the size where the 4x6 board used to clip row 6.
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await pumpGame(tester, const MemoryGame());
      await flushFontCallbacks(tester);
      await tapText(tester, 'ابدأ اللعبة 🚀');
      await pickPlayersAndStart(tester, ['أحمد', 'منى', 'كريم']);
      expect(debugBoardOf(tester).length, 24);
      final cells = find.descendant(
          of: find.byType(GridView), matching: find.byType(GestureDetector));
      expect(cells, findsNWidgets(24),
          reason: 'rows clipped by non-scrollable grid');
      final size = tester.getSize(cells.first);
      expect(size.width, greaterThanOrEqualTo(48),
          reason: 'cell too narrow: $size');
      expect(size.height, greaterThanOrEqualTo(48),
          reason: 'cell too short: $size');
      // Bottom-most card must be fully inside the screen.
      final last = tester.getRect(cells.at(23));
      expect(last.bottom, lessThanOrEqualTo(640),
          reason: 'last row clipped: $last');
      await flushFontCallbacks(tester);
    });
  });

  group('who am i: hints, answer, turn rotation', () {
    testWidgets('hint counter, reveal, correct/wrong advance turns',
        (tester) async {
      await pumpGame(tester, const WhoAmIGame());
      await flushFontCallbacks(tester);
      // Stage 1: intro. Stage 2: lobby. Both need game data loaded first.
      await untilFound(tester, 'ابدأ اللعبة 🚀');
      await tapText(tester, 'ابدأ اللعبة 🚀');
      await untilFound(tester, 'اختار شلتك وابدأ!');
      await tapText(tester, 'اختار شلتك وابدأ!');
      await fixedPumps(tester, 6); // navigation to player selection
      await pickPlayersAndStart(tester);

      expect(find.text('دوره الحين'), findsOneWidget);
      await tapText(tester, 'تلميح 💡');
      expect(find.textContaining('تلميح 1 من'), findsOneWidget);

      await tapText(tester, 'اكشف الجواب');
      expect(find.text('هل عرف أحمد؟'), findsOneWidget);

      // Correct: awards points and passes the turn to منى.
      await tapContaining(tester, 'عرفها ✅');
      expect(find.text('هل عرف أحمد؟'), findsNothing);

      await tapText(tester, 'اكشف الجواب');
      expect(find.text('هل عرف منى؟'), findsOneWidget);

      // Wrong: no points, back to an unanswered card afterwards.
      await tapText(tester, 'ما عرفش ❌');
      expect(find.text('اكشف الجواب'), findsOneWidget);
      await flushFontCallbacks(tester);
    });
  });

  group('password: full 2-round match', () {
    testWidgets('reveal, correct guess scoring, no-guess, winner, replay',
        (tester) async {
      await pumpGame(tester, const PasswordGame());
      await flushFontCallbacks(tester);
      await tapText(tester, 'ابدأ اللعبة 🚀');
      await pickPlayersAndStart(tester);

      // Round 1: أحمد is clue-giver (first player).
      expect(find.text('الجولة 1 من 2'), findsOneWidget);
      expect(find.textContaining('صاحب كلمة السر: أحمد'), findsOneWidget);

      // Regression: before the clue-giver reveals the word, scoring and
      // skipping are gated - premature taps must not score or advance.
      await tester.tap(find.text('محصلش تخمين'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('الجولة 1 من 2'), findsOneWidget);
      expect(find.text('مين اللي خمن صح؟'), findsNothing);
      await tester.tap(find.text('خمنوها صح'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('مين اللي خمن صح؟'), findsNothing);
      expect(find.text('الجولة 1 من 2'), findsOneWidget);

      await tapText(tester, 'شوف الكلمة');
      expect(find.text('خمنوها صح'), findsOneWidget);

      await tapText(tester, 'خمنوها صح');
      expect(find.text('مين اللي خمن صح؟'), findsOneWidget);
      await tapText(tester, 'منى');

      // Round 2: منى is clue-giver; nobody guesses.
      expect(find.text('الجولة 2 من 2'), findsOneWidget);
      expect(find.textContaining('صاحب كلمة السر: منى'), findsOneWidget);
      await tapText(tester, 'شوف الكلمة');
      await tapText(tester, 'محصلش تخمين');

      // Final: منى wins 2-1 (guesser +2, clue-giver أحمد +1).
      expect(find.text('الفايز: منى'), findsOneWidget);
      expect(find.text('منى: 2'), findsOneWidget);
      expect(find.text('أحمد: 1'), findsOneWidget);

      await tapText(tester, 'العب تاني');
      expect(find.text('ابدأ اللعبة 🚀'), findsOneWidget);
      await flushFontCallbacks(tester);
    });
  });

  group('spy: full 3-round match', () {
    testWidgets('deal pass-around, vote, reveal, rounds end, replay',
        (tester) async {
      await pumpGame(tester, const SpyGame());
      await flushFontCallbacks(tester);
      await tapText(tester, 'ابدأ اللعبة 🚀');
      await pickPlayersAndStart(tester, ['أحمد', 'منى', 'كريم']);

      for (var round = 1; round <= 3; round++) {
        expect(find.text('الجولة $round من 3'), findsOneWidget);
        // Deal: each of the 3 players peeks and passes.
        for (var deal = 0; deal < 3; deal++) {
          await tapText(tester, 'شوف كارتك');
          await tapText(
              tester, deal == 2 ? 'ابدأوا الأسئلة' : 'خبّي وادّي للي بعده');
        }
        // Vote: accuse أحمد; either reveal text ends the round.
        await tapText(tester, 'أحمد');
        final caught = find.text('اتمسك! 🎯').evaluate().isNotEmpty;
        final escaped = find.text('هرب منكم! 🏃').evaluate().isNotEmpty;
        expect(caught || escaped, isTrue,
            reason: 'no reveal after voting');
        await tapText(tester,
            round < 3 ? 'الجولة اللي بعدها' : 'النتيجة النهائية');
      }

      // Final screen: someone won or it is a tie; replay returns to intro.
      final winner = find.textContaining('الفايز:').evaluate().isNotEmpty;
      final tie = find.textContaining('تعادل:').evaluate().isNotEmpty;
      expect(winner || tie, isTrue, reason: 'no final score screen');
      await tapText(tester, 'العب تاني');
      expect(find.text('ابدأ اللعبة 🚀'), findsOneWidget);
      await flushFontCallbacks(tester);
    });
  });

  group('undercover: full match', () {
    testWidgets('deal, vote rounds, oustings, win screen, replay',
        (tester) async {
      await pumpGame(tester, const UndercoverGame(seed: 11));
      await flushFontCallbacks(tester);
      await tapText(tester, 'ابدأ اللعبة 🚀');
      await pickPlayersAndStart(tester, ['أحمد', 'منى', 'كريم', 'سارة']);

      // Deal: 4 players peek their private card and pass.
      const names = ['أحمد', 'منى', 'كريم', 'سارة'];
      for (var deal = 0; deal < 4; deal++) {
        await tapText(tester, 'شوف كلمتك يا ${names[deal]}');
        await tapText(
            tester, deal == 3 ? 'ابدأ الوصف' : 'اللاعب اللي بعده');
      }

      // Vote rounds until a win screen: each voter taps the first candidate;
      // handle ousted reveal and the Mr. White crack attempt on the way.
      var guard = 0;
      while (find.text('العب تاني').evaluate().isEmpty && guard < 12) {
        guard++;
        if (find.text('مستر وايت انكشف! 👤').evaluate().isNotEmpty) {
          await tester.tap(find.byType(FunkyButton).first);
          await tester.pump(const Duration(milliseconds: 120));
          await flushFontCallbacks(tester);
        } else if (find.text('كمّلوا').evaluate().isNotEmpty) {
          await tapText(tester, 'كمّلوا');
        } else {
          final listView = find.byType(ListView);
          expect(listView, findsOneWidget,
              reason: 'expected a voting ballot');
          await tester.tap(find
              .descendant(of: listView, matching: find.byType(Text))
              .first);
          await tester.pump(const Duration(milliseconds: 120));
          await flushFontCallbacks(tester);
        }
      }

      // Win screen with one of the three official outcomes, then replay.
      final civWin = find.text('المدنيون كسبوا! 🎉').evaluate().isNotEmpty;
      final infilWin = find.text('المتسللون كسبوا! 🥷').evaluate().isNotEmpty;
      final whiteWin =
          find.text('مستر وايت خمّن الكلمة! 👤').evaluate().isNotEmpty;
      expect(civWin || infilWin || whiteWin, isTrue,
          reason: 'no win screen after $guard vote rounds');
      await tapText(tester, 'العب تاني');
      expect(find.text('ابدأ اللعبة 🚀'), findsOneWidget);
      await flushFontCallbacks(tester);
    });
  });

  group('undercover: mr white free-text guess and concealment', () {
    const names = ['أحمد', 'منى', 'كريم', 'سارة', 'عمر', 'ليلى'];

    /// Replicates the game's seeded draws to learn roles and the word pair.
    (List<String> roles, String civWord) expectedDeal() {
      final rng = Random(11);
      final roles = UndercoverGame.rolesFor(names.length, rng);
      final pairIndex = rng.nextInt(UndercoverGame.wordPairs.length);
      return (roles, UndercoverGame.wordPairs[pairIndex][0]);
    }

    Future<void> dealAll(WidgetTester tester) async {
      for (var deal = 0; deal < names.length; deal++) {
        await tapText(tester, 'شوف كلمتك يا ${names[deal]}');
        await tapText(tester,
            deal == names.length - 1 ? 'ابدأ الوصف' : 'اللاعب اللي بعده');
      }
    }

    Future<void> voteOutMrWhite(WidgetTester tester, String mwName) async {
      for (final voter in names) {
        if (voter == mwName) {
          // Mr. White cannot vote for himself; vote the first other player.
          await tapText(tester, names.firstWhere((n) => n != mwName));
        } else {
          await tapText(tester, mwName);
        }
      }
    }

    testWidgets('ousted mr white wins by normalized free-text guess',
        (tester) async {
      final (roles, civWord) = expectedDeal();
      final mwName = names[roles.indexOf(UndercoverGame.mrWhite)];
      final variant = civWord.contains('ة')
          ? civWord.replaceAll('ة', 'ه')
          : (civWord.contains('ا')
              ? civWord.replaceFirst('ا', 'أ')
              : ' $civWord ');
      await pumpGame(tester, const UndercoverGame(seed: 11));
      await flushFontCallbacks(tester);
      await tapText(tester, 'ابدأ اللعبة 🚀');
      await pickPlayersAndStart(tester, names);
      await dealAll(tester);
      await voteOutMrWhite(tester, mwName);

      expect(find.text('مستر وايت انكشف! 👤'), findsOneWidget);
      await tester.enterText(find.byType(TextField), variant);
      await tapText(tester, 'خمّن!');
      expect(find.text('مستر وايت خمّن الكلمة! 👤'), findsOneWidget);
      expect(find.text('العب تاني'), findsOneWidget);
      await flushFontCallbacks(tester);
    });

    testWidgets('wrong guess keeps the game going; ousted player stops voting',
        (tester) async {
      final (roles, civWord) = expectedDeal();
      final mwName = names[roles.indexOf(UndercoverGame.mrWhite)];
      await pumpGame(tester, const UndercoverGame(seed: 11));
      await flushFontCallbacks(tester);
      await tapText(tester, 'ابدأ اللعبة 🚀');
      await pickPlayersAndStart(tester, names);
      await dealAll(tester);
      await voteOutMrWhite(tester, mwName);

      expect(find.text('مستر وايت انكشف! 👤'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'كلام فاضي خالص');
      await tapText(tester, 'خمّن!');

      // Wrong guess: no immediate Mr. White win; his ousted screen shows,
      // then the game proceeds to the next vote without him.
      expect(find.text('مستر وايت خمّن الكلمة! 👤'), findsNothing);
      expect(find.text('كمّلوا'), findsOneWidget);
      await tapText(tester, 'كمّلوا');
      // Next ballot exists and the ousted Mr. White never votes again.
      var guard = 0;
      while (find.text('العب تاني').evaluate().isEmpty && guard < 30) {
        guard++;
        expect(find.textContaining('يا $mwName،').evaluate().isEmpty, isTrue,
            reason: 'ousted player was asked to vote');
        if (find.text('مستر وايت انكشف! 👤').evaluate().isNotEmpty) {
          await tester.enterText(find.byType(TextField), civWord);
          await tapText(tester, 'خمّن!');
        } else if (find.text('كمّلوا').evaluate().isNotEmpty) {
          await tapText(tester, 'كمّلوا');
        } else {
          final listView = find.byType(ListView);
          expect(listView, findsOneWidget, reason: 'expected a ballot');
          await tester.tap(find
              .descendant(of: listView, matching: find.byType(Text))
              .first);
          await tester.pump(const Duration(milliseconds: 120));
          await flushFontCallbacks(tester);
        }
      }
      expect(find.text('العب تاني'), findsOneWidget);
      await flushFontCallbacks(tester);
    });

    testWidgets('deal concealment: word hidden again after every pass',
        (tester) async {
      final (roles, civWord) = expectedDeal();
      final ucWord = UndercoverGame.wordPairs.firstWhere(
          (p) => p[0] == civWord)[1];
      await pumpGame(tester, const UndercoverGame(seed: 11));
      await flushFontCallbacks(tester);
      await tapText(tester, 'ابدأ اللعبة 🚀');
      await pickPlayersAndStart(tester, names);
      for (var deal = 0; deal < names.length; deal++) {
        await tapText(tester, 'شوف كلمتك يا ${names[deal]}');
        // A word (or the Mr. White no-word notice) is visible only now.
        if (deal + 1 < names.length) {
          await tapText(tester, 'اللاعب اللي بعده');
          // Concealed again for the next player.
          expect(find.text(civWord), findsNothing);
          expect(find.text(ucWord), findsNothing);
          expect(find.text('🤫'), findsWidgets);
        }
      }
      await flushFontCallbacks(tester);
    });
  });

  group('proverb: steal mechanic and full match', () {
    testWidgets('wrong pick steals turn, correct scores, winner, replay',
        (tester) async {
      final order = List.generate(ProverbGame.proverbs.length, (i) => i)
        ..shuffle(Random(13));
      await pumpGame(tester, const ProverbGame());
      await flushFontCallbacks(tester);
      await tapText(tester, 'ابدأ اللعبة 🚀');
      await pickPlayersAndStart(tester);

      // Round 1 (proverb order[0]): أحمد picks a WRONG option, منى steals.
      final correct1 = ProverbGame.proverbs[order[0]].end;
      final options1 =
          ProverbGame.buildOptions(ProverbGame.proverbs, order[0], 5);
      final wrong1 = options1.firstWhere((o) => o != correct1);
      expect(find.text('دور: أحمد'), findsOneWidget);
      await tapText(tester, wrong1);
      expect(find.textContaining('غلط!'), findsOneWidget);
      expect(find.text('دور: منى'), findsOneWidget);
      await tapText(tester, correct1);
      expect(find.textContaining('الإجابة:'), findsOneWidget);
      await tapText(tester, 'المثل اللي بعده');

      // Round 2 (proverb order[1]): منى picks correctly on first try.
      final correct2 = ProverbGame.proverbs[order[1]].end;
      expect(find.text('دور: منى'), findsOneWidget);
      await tapText(tester, correct2);
      await tapText(tester, 'النتيجة النهائية');

      // منى 2 (steal + own round), أحمد 0.
      expect(find.text('الفايز: منى'), findsOneWidget);
      expect(find.text('منى: 2'), findsOneWidget);
      expect(find.text('أحمد: 0'), findsOneWidget);

      await tapText(tester, 'العب تاني');
      expect(find.text('ابدأ اللعبة 🚀'), findsOneWidget);
      await flushFontCallbacks(tester);
    });
  });

  group('who said: full 3-round match', () {
    testWidgets('secret answer, group vote, reveal, scoring, replay',
        (tester) async {
      await pumpGame(tester, const WhoSaidGame());
      await flushFontCallbacks(tester);
      await tapText(tester, 'ابدأ اللعبة 🚀');
      await pickPlayersAndStart(tester, ['أحمد', 'منى', 'كريم']);

      // Round 1: أحمد answers secretly; group identifies him correctly.
      expect(find.text('الجولة 1 من 3'), findsOneWidget);
      await tapText(tester, 'شوف سؤالك');
      final options1 = WhoSaidGame.questions
          .map((q) => q.options.first)
          .toList();
      await tapText(tester, options1.firstWhere((o) =>
          find.text(o).evaluate().isNotEmpty));
      expect(find.text('مين اللي جاوب كده؟ 👀'), findsOneWidget);
      await tapText(tester, 'أحمد'); // correct: أحمد is the answerer
      expect(find.text('عرفتوه! 🎯'), findsOneWidget);
      await tapText(tester, 'الجولة اللي بعدها');

      // Round 2: منى answers; group accuses the wrong player.
      await tapText(tester, 'شوف سؤالك');
      final visible2 = WhoSaidGame.questions
          .map((q) => q.options.first)
          .firstWhere((o) => find.text(o).evaluate().isNotEmpty);
      await tapText(tester, visible2);
      await tapText(tester, 'كريم'); // wrong: answerer is منى
      expect(find.text('ضحك عليكم! 😎'), findsOneWidget);
      await tapText(tester, 'الجولة اللي بعدها');

      // Round 3: كريم answers; group identifies him.
      await tapText(tester, 'شوف سؤالك');
      final visible3 = WhoSaidGame.questions
          .map((q) => q.options.first)
          .firstWhere((o) => find.text(o).evaluate().isNotEmpty);
      await tapText(tester, visible3);
      await tapText(tester, 'كريم'); // correct
      expect(find.text('عرفتوه! 🎯'), findsOneWidget);
      await tapText(tester, 'النتيجة النهائية');

      // Scores: R1 others +2 (منى 2, كريم 2); R2 منى +3; R3 others +2
      // (أحمد 2, منى +2). Totals: منى 7, كريم 2, أحمد 2.
      expect(find.text('الفايز: منى'), findsOneWidget);
      expect(find.text('منى: 7'), findsOneWidget);
      expect(find.text('أحمد: 2'), findsOneWidget);
      expect(find.text('كريم: 2'), findsOneWidget);

      await tapText(tester, 'العب تاني');
      expect(find.text('ابدأ اللعبة 🚀'), findsOneWidget);
      await flushFontCallbacks(tester);
    });
  });

  group('mafia: full match and concealment', () {
    const names = ['أحمد', 'منى', 'كريم', 'سارة', 'عمر', 'ليلى'];

    Future<void> dealAllMafia(WidgetTester tester) async {
      for (var deal = 0; deal < names.length; deal++) {
        await tapText(tester, 'شوف دورك يا ${names[deal]}');
        await tapText(tester,
            deal == names.length - 1 ? 'ابدأ الليل 🌙' : 'اللاعب اللي بعده');
      }
    }

    testWidgets('deal concealment: role hidden again after every pass',
        (tester) async {
      await pumpGame(tester, const MafiaGame(seed: 5));
      await flushFontCallbacks(tester);
      await tapText(tester, 'ابدأ اللعبة 🚀');
      await pickPlayersAndStart(tester, names);
      for (var deal = 0; deal < names.length; deal++) {
        await tapText(tester, 'شوف دورك يا ${names[deal]}');
        if (deal + 1 < names.length) {
          await tapText(tester, 'اللاعب اللي بعده');
          // Concealed again for the next player: no role text visible.
          expect(find.text('مافيا 🔫'), findsNothing);
          expect(find.text('دكتور 🩺'), findsNothing);
          expect(find.text('محقق 🕵'), findsNothing);
          expect(find.text('من المدنيين 🧑'), findsNothing);
          expect(find.textContaining('اللي يشوف'), findsWidgets);
        }
      }
      await flushFontCallbacks(tester);
    });

    testWidgets(
        'night/day cycle, eliminated players never vote, win screen, replay',
        (tester) async {
      await pumpGame(tester, const MafiaGame(seed: 5));
      await flushFontCallbacks(tester);
      await tapText(tester, 'ابدأ اللعبة 🚀');
      await pickPlayersAndStart(tester, names);
      await dealAllMafia(tester);

      final gone = <String>{};
      var guard = 0;
      while (find.text('العب تاني').evaluate().isEmpty && guard < 200) {
        guard++;
        if (find.text('كمّلوا').evaluate().isNotEmpty) {
          // Eliminated screen: record who was ousted (name is the only
          // player-name text on this screen).
          final elim = names.firstWhere(
              (n) => !gone.contains(n) && find.text(n).evaluate().isNotEmpty);
          gone.add(elim);
          await tapText(tester, 'كمّلوا');
        } else if (find.text('ابدأ التصويت ⚖️').evaluate().isNotEmpty) {
          await tapText(tester, 'ابدأ التصويت ⚖️');
        } else if (find
            .textContaining('شوف مهمتك يا')
            .evaluate()
            .isNotEmpty) {
          // Night gate: never addresses an eliminated player.
          for (final g in gone) {
            expect(find.text('شوف مهمتك يا $g').evaluate().isEmpty, isTrue,
                reason: 'eliminated player asked to act at night');
          }
          await tapContaining(tester, 'شوف مهمتك يا');
        } else if (find.text('خبّي وادّي للي بعده').evaluate().isNotEmpty) {
          await tapText(tester, 'خبّي وادّي للي بعده');
        } else if (find
            .text('تمام، عدّي للي بعده')
            .evaluate()
            .isNotEmpty) {
          await tapText(tester, 'تمام، عدّي للي بعده');
        } else {
          final listView = find.byType(ListView);
          expect(listView, findsOneWidget,
              reason: 'expected a night action or day ballot');
          // Day ballot: eliminated players are not candidates.
          if (find.textContaining('مشكوك فيه').evaluate().isNotEmpty) {
            for (final g in gone) {
              expect(find.text(g).evaluate().isEmpty, isTrue,
                  reason: 'eliminated player still on the ballot');
            }
          }
          await tester.tap(find
              .descendant(of: listView, matching: find.byType(Text))
              .first);
          await tester.pump(const Duration(milliseconds: 120));
          await flushFontCallbacks(tester);
        }
      }

      final villageWin =
          find.text('المدنيون كسبوا! 🎉').evaluate().isNotEmpty;
      final mafiaWin = find.text('المافيا كسبت! 🔫').evaluate().isNotEmpty;
      expect(villageWin || mafiaWin, isTrue,
          reason: 'no win screen after $guard steps');
      await tapText(tester, 'العب تاني');
      expect(find.text('ابدأ اللعبة 🚀'), findsOneWidget);
      await flushFontCallbacks(tester);
    });
  });
  group('would rather: vote concealment, tally, rounds, end, replay, back',
      () {
    /// Mirrors the game's seeded question order for deterministic picks.
    List<int> seededOrder(int seed) =>
        List.generate(WouldRatherGame.questions.length, (i) => i)
          ..shuffle(Random(seed));

    testWidgets(
        'per-player gate hides options between voters, reveal tally correct',
        (tester) async {
      const names = ['أحمد', 'منى', 'كريم'];
      await pumpGame(tester, const WouldRatherGame(seed: 9));
      await flushFontCallbacks(tester);
      await tapText(tester, 'ابدأ اللعبة 🚀');
      await pickPlayersAndStart(tester, names);

      final q = WouldRatherGame.questions[seededOrder(9)[0]];
      expect(find.text('السؤال 1'), findsOneWidget);
      expect(find.text(q.a), findsOneWidget);
      expect(find.text(q.b), findsOneWidget);

      await tapText(tester, 'ابدأ التصويت ⚖️');
      // Gate for أحمد: options concealed before he opens his gate.
      expect(find.text(q.a), findsNothing);
      expect(find.text(q.b), findsNothing);
      await tapText(tester, 'صوّت يا أحمد');
      expect(find.text(q.a), findsOneWidget);
      await tapText(tester, q.a); // أحمد -> A
      // Concealed again for منى.
      expect(find.text(q.a), findsNothing);
      expect(find.text(q.b), findsNothing);
      await tapText(tester, 'صوّت يا منى');
      await tapText(tester, q.b); // منى -> B
      await tapText(tester, 'صوّت يا كريم');
      await tapText(tester, q.a); // كريم -> A

      // Reveal: exact tallies and team membership.
      expect(find.text('2 صوت'), findsOneWidget);
      expect(find.text('1 صوت'), findsOneWidget);
      expect(find.text('أحمد، كريم'), findsOneWidget);
      expect(find.text('الأغلبية مع الاختيار الأول 🔥'), findsOneWidget);

      await tapText(tester, 'السؤال اللي بعده ⏭');
      expect(find.text('السؤال 2'), findsOneWidget);
      // New round resets: question visible again, no stale reveal.
      expect(find.text('أحمد، كريم'), findsNothing);
    });

    testWidgets('full session ends after names*3 rounds, replay resets',
        (tester) async {
      const names = ['أحمد', 'منى'];
      await pumpGame(tester, const WouldRatherGame(seed: 9));
      await flushFontCallbacks(tester);
      await tapText(tester, 'ابدأ اللعبة 🚀');
      await pickPlayersAndStart(tester, names);

      for (var round = 1; round <= 6; round++) {
        expect(find.text('السؤال $round'), findsOneWidget);
        await tapText(tester, 'ابدأ التصويت ⚖️');
        for (final name in names) {
          await tapText(tester, 'صوّت يا $name');
          // Vote for whichever option is on top (A) every time.
          final q = WouldRatherGame
              .questions[seededOrder(9)[round - 1]];
          await tapText(tester, q.a);
        }
        await tapText(tester, 'السؤال اللي بعده ⏭');
      }
      expect(find.text('خلصت الأسئلة! 🎉'), findsOneWidget);
      await tapText(tester, 'العب تاني');
      expect(find.text('ابدأ اللعبة 🚀'), findsOneWidget);
    });

    testWidgets('back navigation from game pops to caller', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme:
              ThemeData(fontFamilyFallback: const ['Noto Color Emoji']),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (_) => const Directionality(
                        textDirection: TextDirection.rtl,
                        child: WouldRatherGame(seed: 9),
                      ),
                    ),
                  ),
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        ),
      );
      await fixedPumps(tester);
      await tapText(tester, 'OPEN');
      await flushFontCallbacks(tester);
      expect(find.text('ابدأ اللعبة 🚀'), findsOneWidget);
      final back = find.byType(BackButton);
      expect(back, findsOneWidget);
      await tester.tap(back, warnIfMissed: false);
      await fixedPumps(tester, 8);
      expect(find.byType(WouldRatherGame), findsNothing);
      expect(find.text('OPEN'), findsOneWidget);
    });
  });

  group('never have i: confession tally, reader rotation, end, replay',
      () {
    List<int> seededOrder(int seed) =>
        List.generate(NeverHaveIGame.statements.length, (i) => i)
          ..shuffle(Random(seed));

    testWidgets(
        'taps increment exact confession counts, reader rotates, end sorted, replay',
        (tester) async {
      const names = ['أحمد', 'منى', 'كريم'];
      await pumpGame(tester, const NeverHaveIGame(seed: 13));
      await flushFontCallbacks(tester);
      await tapText(tester, 'ابدأ اللعبة 🚀');
      await pickPlayersAndStart(tester, names);

      // First statement matches the seeded order; reader is أحمد.
      final first = NeverHaveIGame.statements[seededOrder(13)[0]];
      expect(find.text(first), findsOneWidget);
      expect(find.textContaining('القارئ: أحمد'), findsOneWidget);
      expect(find.text('0 اعتراف'), findsNWidgets(3));

      // أحمد confesses once, منى twice this turn.
      await tapText(tester, 'أحمد');
      expect(find.text('1 اعتراف'), findsOneWidget);
      await tapText(tester, 'منى');
      await tapText(tester, 'منى');
      expect(find.text('2 اعتراف'), findsOneWidget);
      expect(find.text('0 اعتراف'), findsOneWidget); // كريم untouched

      await tapText(tester, 'الجملة اللي بعدها ⏭');
      expect(find.textContaining('القارئ: منى'), findsOneWidget);
      // Statement advanced, no repeat of the first one.
      expect(find.text(first), findsNothing);

      // Play out the remaining 8 turns (9 total = 3 players x 3).
      for (var turn = 2; turn <= 9; turn++) {
        expect(find.textContaining('الجملة $turn'), findsOneWidget);
        if (turn < 9) await tapText(tester, 'الجملة اللي بعدها ⏭');
      }
      // Last "next" tap ends the session.
      await tapText(tester, 'الجملة اللي بعدها ⏭');
      expect(find.text('نتيجة الاعترافات! 🎉'), findsOneWidget);
      expect(find.text('منى: 2 اعتراف'), findsOneWidget);
      expect(find.text('أحمد: 1 اعتراف'), findsOneWidget);
      expect(find.text('كريم: 0 اعتراف'), findsOneWidget);
      // Sorted: منى (2) listed above أحمد (1) above كريم (0).
      final topMona = tester.getTopLeft(find.text('منى: 2 اعتراف')).dy;
      final topAhmed = tester.getTopLeft(find.text('أحمد: 1 اعتراف')).dy;
      final topKarim = tester.getTopLeft(find.text('كريم: 0 اعتراف')).dy;
      expect(topMona < topAhmed && topAhmed < topKarim, isTrue);

      await tapText(tester, 'العب تاني');
      expect(find.text('ابدأ اللعبة 🚀'), findsOneWidget);
    });
  });
  group('word story: rotation, single-word validation, accumulation, end',
      () {
    Future<void> typeWord(WidgetTester tester, String word) async {
      await tester.enterText(find.byType(TextField), word);
      await fixedPumps(tester, 2);
      await tapText(tester, 'ضيف الكلمة ✍');
    }

    testWidgets(
        'turns rotate, story accumulates in order, multi-word rejected, end + replay',
        (tester) async {
      const names = ['أحمد', 'منى'];
      await pumpGame(tester, const WordStoryGame());
      await flushFontCallbacks(tester);
      await tapText(tester, 'ابدأ اللعبة 🚀');
      await pickPlayersAndStart(tester, names);

      // Rotation: أحمد then منى.
      expect(find.textContaining('الدور على: أحمد'), findsOneWidget);
      // Opener visible before any word.
      expect(find.textContaining('في يوم من الأيام'), findsOneWidget);

      // Multi-word input rejected with the error, story unchanged.
      await typeWord(tester, 'كلمتين مع بعض');
      expect(find.text('كلمة واحدة بس، من غير مسافات!'), findsOneWidget);
      expect(find.textContaining('الدور على: أحمد'), findsOneWidget);

      await typeWord(tester, 'قطة');
      expect(find.textContaining('الدور على: منى'), findsOneWidget);
      expect(find.textContaining('في يوم من الأيام قطة'), findsOneWidget);

      // Play out the remaining 9 words (2 players x 5 total).
      final words = [
        'كلت', 'كشري', 'ورقصت', 'في', 'المطبخ', 'مع', 'بطة', 'وضحكت', 'جدا'
      ];
      for (var i = 0; i < words.length; i++) {
        await typeWord(tester, words[i]);
      }
      expect(find.text('قصتكم جاهزة! 🎉'), findsOneWidget);
      expect(
          find.textContaining(
              'في يوم من الأيام قطة كلت كشري ورقصت في المطبخ مع بطة وضحكت جدا'),
          findsOneWidget);

      await tapText(tester, 'قصة جديدة');
      expect(find.text('ابدأ اللعبة 🚀'), findsOneWidget);
    });
  });

  group('code names: key concealment, turn flow, assassin, win, replay', () {
    const seed = 21;
    (List<String>, List<String>) mirrorDeal() =>
        CodeNamesGame.deal(Random(seed), 'red');

    const redColor = Color(0xFFE0483E);
    const blueColor = Color(0xFF3E7BFA);
    const neutralColor = Color(0xFFB8A88A);
    const assassinColor = Color(0xFF22242E);

    List<Color?> gridColors(WidgetTester tester) {
      final cells = find.descendant(
          of: find.byType(GridView), matching: find.byType(Container));
      return tester
          .widgetList<Container>(cells)
          .map((c) => (c.decoration! as BoxDecoration).color)
          .toList();
    }

    Future<void> startMatch(WidgetTester tester) async {
      // Tall surface so the lazy GridView builds all 25 cells.
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await pumpGame(tester, const CodeNamesGame(seed: seed));
      await flushFontCallbacks(tester);
      await tapText(tester, 'ابدأ اللعبة 🚀');
      await pickPlayersAndStart(
          tester, const ['أحمد', 'منى', 'كريم', 'سارة']);
    }

    Future<void> giveClue(WidgetTester tester, String clue, int count) async {
      await tapText(tester, 'اكتب التلميح ✍');
      await tester.enterText(find.byType(TextField), clue);
      await fixedPumps(tester, 2);
      if (count != 2) await tapText(tester, '$count');
      await tapText(tester, 'اعرض التلميح للفريق');
    }

    testWidgets(
        'gate conceals key; key map matches deal; clue entry hides grid; neutral guess swaps turn',
        (tester) async {
      final (words, key) = mirrorDeal();
      await startMatch(tester);

      // Red gate: no grid at all, only the spymaster's open button.
      expect(find.text('الدور على الفريق الأحمر'), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
      await tapText(tester, 'افتح الخريطة يا أحمد');

      // Key map: every cell color matches the mirrored deal exactly.
      expect(find.textContaining('الخريطة السرية'), findsOneWidget);
      final colors = gridColors(tester);
      expect(colors.length, 25);
      for (var i = 0; i < 25; i++) {
        final expected = key[i] == 'red'
            ? redColor
            : key[i] == 'blue'
                ? blueColor
                : key[i] == 'neutral'
                    ? neutralColor
                    : assassinColor;
        expect(colors[i], expected, reason: 'cell $i (${words[i]})');
      }

      // A tap on the key map must not register a guess.
      final tapIdx = key.indexOf('red');
      await tester.tap(find.text(words[tapIdx]), warnIfMissed: false);
      await fixedPumps(tester, 2);

      // Clue entry: grid fully concealed (not built), key text gone.
      await tapText(tester, 'اكتب التلميح ✍');
      expect(find.byType(GridView), findsNothing);
      expect(find.textContaining('الخريطة السرية'), findsNothing);

      // Invalid clues blocked at entry (labeled house rule).
      await tester.enterText(find.byType(TextField), words[0]);
      await fixedPumps(tester, 2);
      await tapText(tester, 'اعرض التلميح للفريق');
      expect(
          find.text('التلميح ميبقاش كلمة من اللوحة'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'كلمتين مع بعض');
      await fixedPumps(tester, 2);
      await tapText(tester, 'اعرض التلميح للفريق');
      expect(find.text('التلميح كلمة واحدة بس'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'حاجة');
      await fixedPumps(tester, 2);
      await tapText(tester, 'اعرض التلميح للفريق');

      // Public guessing: clue visible, grid words visible, NO key colors.
      expect(find.textContaining('التلميح: حاجة (2)'), findsOneWidget);
      expect(find.textContaining('فاضل 3 تخمينة'), findsOneWidget);
      final pubColors = gridColors(tester);
      expect(pubColors.length, 25);
      expect(
          pubColors
              .where((c) =>
                  c == redColor || c == blueColor || c == assassinColor)
              .length,
          0,
          reason: 'no key colors may leak on the public grid');

      // Correct red guess consumes one guess, turn stays red.
      await tester.tap(find.text(words[tapIdx]), warnIfMissed: false);
      await fixedPumps(tester);
      expect(find.textContaining('فاضل 2 تخمينة'), findsOneWidget);

      // Neutral guess ends the turn: blue gate, key concealed again.
      final neutralIdx = key.indexOf('neutral');
      await tester.tap(find.text(words[neutralIdx]), warnIfMissed: false);
      await fixedPumps(tester);
      expect(find.text('الدور على الفريق الأزرق'), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
      expect(find.text('افتح الخريطة يا منى'), findsOneWidget);
      expect(find.textContaining('التلميح: حاجة'), findsNothing);
    });

    testWidgets(
        'assassin guess ends the game instantly for the guessing team; replay resets everything',
        (tester) async {
      final (words, key) = mirrorDeal();
      await startMatch(tester);
      await tapText(tester, 'افتح الخريطة يا أحمد');
      await giveClue(tester, 'حاجة', 1);
      expect(find.textContaining('فاضل 2 تخمينة'), findsOneWidget);
      final assassinIdx = key.indexOf('assassin');
      await tester.tap(find.text(words[assassinIdx]),
          warnIfMissed: false);
      await fixedPumps(tester);
      // Red guessed the assassin: blue wins immediately.
      expect(find.text('الفريق الأزرق كسب! 🎉'), findsOneWidget);
      expect(find.text('منى، سارة'), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
      // Replay: full reset to intro, no key or clue left visible.
      await tapText(tester, 'العب تاني');
      expect(find.text('ابدأ اللعبة 🚀'), findsOneWidget);
      expect(find.text('الخريطة السرية - أحمد بس! 🤫'), findsNothing);
      expect(find.textContaining('التلميح: حاجة'), findsNothing);
    });

    testWidgets('revealing every red agent wins across turn swaps',
        (tester) async {
      final (words, key) = mirrorDeal();
      final redIdxs = [
        for (var i = 0; i < 25; i++)
          if (key[i] == 'red') i
      ];
      expect(redIdxs.length, 9);
      await startMatch(tester);

      // Red turn 1: clue count 4 -> 5 guesses, tap 5 red cells.
      await tapText(tester, 'افتح الخريطة يا أحمد');
      await giveClue(tester, 'حاجة', 4);
      for (var k = 0; k < 5; k++) {
        await tester.tap(find.text(words[redIdxs[k]]),
            warnIfMissed: false);
        await fixedPumps(tester, 2);
      }
      // Guesses exhausted: turn swaps to the blue gate.
      expect(find.text('افتح الخريطة يا منى'), findsOneWidget);

      // Blue turn: clue 1, one correct blue guess, then a neutral.
      await tapText(tester, 'افتح الخريطة يا منى');
      await giveClue(tester, 'تانية', 1);
      final blueIdx = key.indexOf('blue');
      await tester.tap(find.text(words[blueIdx]), warnIfMissed: false);
      await fixedPumps(tester, 2);
      expect(find.textContaining('فاضل 1 تخمينة'), findsOneWidget);
      final neutralIdx = key.indexOf('neutral');
      await tester.tap(find.text(words[neutralIdx]),
          warnIfMissed: false);
      await fixedPumps(tester, 2);

      // Red turn 2: clue 4, remaining 4 red cells -> red wins.
      await tapText(tester, 'افتح الخريطة يا أحمد');
      await giveClue(tester, 'الأخيرة', 4);
      for (var k = 5; k < 9; k++) {
        await tester.tap(find.text(words[redIdxs[k]]),
            warnIfMissed: false);
        await fixedPumps(tester, 2);
      }
      expect(find.text('الفريق الأحمر كسب! 🎉'), findsOneWidget);
      expect(find.text('أحمد، كريم'), findsOneWidget);
    });

    testWidgets('back navigation from game pops to caller', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme:
              ThemeData(fontFamilyFallback: const ['Noto Color Emoji']),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (_) => const Directionality(
                        textDirection: TextDirection.rtl,
                        child: CodeNamesGame(seed: seed),
                      ),
                    ),
                  ),
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        ),
      );
      await fixedPumps(tester);
      await tapText(tester, 'OPEN');
      await flushFontCallbacks(tester);
      expect(find.text('ابدأ اللعبة 🚀'), findsOneWidget);
      final back = find.byType(BackButton);
      expect(back, findsOneWidget);
      await tester.tap(back, warnIfMissed: false);
      await fixedPumps(tester, 8);
      expect(find.byType(CodeNamesGame), findsNothing);
      expect(find.text('OPEN'), findsOneWidget);
    });
  });
}
