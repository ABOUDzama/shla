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
import 'package:shella/games/offline/proverb_game.dart';
import 'package:shella/games/offline/who_said_game.dart';
import 'package:shella/games/offline/most_likely_game.dart';
import 'package:shella/games/offline/taboo_game.dart';
import 'package:shella/games/offline/emoji_guess_game.dart';
import 'package:shella/games/offline/who_am_i_game.dart';

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
      await tapText(tester, 'شوف الكلمة');
      expect(find.text('خمنوها صح'), findsOneWidget);

      await tapText(tester, 'خمنوها صح');
      expect(find.text('مين اللي خمن صح؟'), findsOneWidget);
      await tapText(tester, 'منى');

      // Round 2: منى is clue-giver; nobody guesses.
      expect(find.text('الجولة 2 من 2'), findsOneWidget);
      expect(find.textContaining('صاحب كلمة السر: منى'), findsOneWidget);
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
}
