import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/services/settings_service.dart';
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
}
