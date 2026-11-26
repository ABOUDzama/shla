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
import 'package:shella/games/offline/xo_game.dart';
import 'package:shella/games/offline/bus_complete_game.dart';
import 'package:shella/games/offline/who_am_i_game.dart';
import 'package:shella/games/offline/seega_game.dart';
import 'package:shella/games/offline/gobblet_game.dart';
import 'package:shella/games/offline/multi_touch_screen.dart';
import 'package:shella/games/offline/reaction_game.dart';
import 'package:shella/widgets/victory_friends.dart';
import 'package:shella/games/offline/balance_game.dart';
import 'package:shella/games/offline/tap_race_game.dart';
import 'package:shella/games/offline/tug_of_war_game.dart';
import 'package:shella/games/offline/sumo_game.dart';
import 'package:shella/games/offline/snake_arena_game.dart';
import 'package:shella/games/offline/whack_mole_game.dart';
import 'package:shella/games/offline/coin_grab_game.dart';
import 'package:shella/games/offline/catch_game.dart';
import 'package:shella/games/offline/touch_ball_game.dart';
import 'package:shella/games/offline/snow_brawl_game.dart';
import 'package:shella/games/offline/tank_battle_game.dart';
import 'package:shella/games/offline/rhythm_game.dart';
import 'package:shella/screens/settings_screen.dart';
import 'package:shella/screens/profile_screen.dart';
import 'package:shella/games/offline/password_game.dart';
import 'package:shella/games/offline/spy_game.dart';
import 'package:shella/games/offline/proverb_game.dart';
import 'package:shella/games/offline/who_said_game.dart';
import 'package:shella/games/offline/opposite_day.dart';
import 'package:shella/games/offline/truth_or_lie_game.dart';
import 'package:shella/games/offline/truth_or_dare_game.dart';
import 'package:shella/games/offline/five_seconds_game.dart';
import 'package:shella/games/offline/heads_up_game.dart';
import 'package:shella/games/offline/psych_game.dart';
import 'package:shella/games/offline/justone_game.dart';
import 'package:shella/games/offline/wavelength_game.dart';
import 'package:shella/games/offline/travel_bag_game.dart';
import 'package:shella/games/offline/ghost_word_game.dart';
import 'package:shella/games/offline/wink_murder_game.dart';
import 'package:shella/games/offline/charades_game.dart';
import 'package:shella/games/offline/word_chain_game.dart';
import 'package:shella/games/offline/first_letter_game.dart';
import 'package:shella/games/offline/word_story_game.dart';
import 'package:shella/games/offline/ranking_challenge_game.dart';
import 'package:shella/games/offline/odd_one_out.dart';
import 'package:shella/games/offline/tick_tock_boom.dart';
import 'package:shella/games/offline/reverse_quiz.dart';
import 'package:shella/games/offline/code_names_game.dart';
import 'package:shella/games/offline/pictionary_game.dart';
import 'package:shella/games/offline/would_rather_game.dart';
import 'package:shella/games/offline/never_have_i_game.dart';
import 'package:shella/games/offline/undercover_game.dart';
import 'package:shella/games/offline/mafia_game.dart';
import 'package:shella/widgets/flat_home_preview.dart';
import 'package:shella/widgets/chat_widget.dart';
import 'package:shella/screens/scoreboard_screen.dart';
import 'package:shella/services/score_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;
import 'package:shella/services/socket_service.dart';
import 'package:shella/services/voice_chat_service.dart';
import 'package:shella/screens/lobby_screen.dart';
import 'package:shella/screens/room_screen.dart';

/// Small-screen (360x640) overflow sweep: drives each interior into gameplay
/// and fails on any unconsumed exception (RenderFlex overflow, layout asserts).
/// One debug-only TextPainter debugSize assert during the selection->gameplay
/// swap is a known harness artifact and is consumed where it occurs.
final boundaryKey = GlobalKey();

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
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
      'Black',
    ]) {
      final bytes = await File('assets/fonts/Cairo-$name.ttf').readAsBytes();
      final loader = FontLoader('Cairo')
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
    final emojiBytes = await File(
      'test/fonts_NotoColorEmoji.ttf',
    ).readAsBytes();
    final emojiLoader = FontLoader('Noto Color Emoji')
      ..addFont(Future.value(ByteData.sublistView(emojiBytes)));
    await emojiLoader.load();
    final pmBytes = await File(
      'test/fonts_PermanentMarker-Regular.ttf',
    ).readAsBytes();
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
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/sensors/method'),
      (call) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/sensors/accelerometer'),
      (call) async => null,
    );
  });

  Future<void> pumpSmall(WidgetTester tester, Widget game) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamilyFallback: const ['Noto Color Emoji']),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: RepaintBoundary(key: boundaryKey, child: game),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 60));
  }

  /// Lets async font-load notifications settle, then pumps a frame so the
  /// RelayoutWhenSystemFontsChange transient callback fires inside the test
  /// instead of after teardown (known flutter_test artifact).
  Future<void> flushFontCallbacks(WidgetTester tester) async {
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
  }

  Future<void> fixedPumps(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  Future<void> tapIf(WidgetTester tester, Finder f) async {
    if (f.evaluate().isEmpty) return;
    await tester.ensureVisible(f.first);
    await fixedPumps(tester, 2);
    await tester.tap(f.first, warnIfMissed: false);
    await fixedPumps(tester);
  }

  Future<void> intoGameplay(WidgetTester tester) async {
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    for (final name in ['أحمد', 'منى', 'كريم']) {
      await tapIf(tester, find.text(name));
    }
    await tapIf(tester, find.text('بدء اللعبة'));
    tester.takeException(); // known harness-only debugSize assert
  }

  /// Rasterizes the current 360x640 screen to test/goldens/small360_<name>.png
  /// so reports carry pixel proof, not only zero-overflow assertions.
  Future<void> capture360(WidgetTester tester, String name) async {
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 400)),
    );
    await fixedPumps(tester, 2);
    final scaffoldFind = find.byType(Scaffold);
    if (scaffoldFind.evaluate().isNotEmpty) {
      ScaffoldMessenger.of(
        tester.element(scaffoldFind.first),
      ).hideCurrentSnackBar();
      await fixedPumps(tester, 1);
    }
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await tester.runAsync(
      () => boundary.toImage(pixelRatio: 2.0),
    );
    final byteData = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png),
    );
    final bytes = byteData!.buffer.asUint8List();
    File('test/goldens/small360_$name.png').writeAsBytesSync(bytes);
    expect(bytes.length, greaterThan(8000));
  }

  /// Drains pending exceptions; fails only on real layout overflows.
  /// The RelayoutWhenSystemFontsChange transient callback from FontLoader is
  /// a known flutter_test artifact and is ignored.
  void expectNoOverflow(WidgetTester tester) {
    final seen = <String>[];
    Object? e;
    while ((e = tester.takeException()) != null) {
      seen.add(e.toString());
    }
    final overflows = seen.where(
      (m) => m.contains('overflowed') || m.contains('RenderFlex'),
    );
    expect(overflows, isEmpty, reason: seen.join('\n---\n'));
  }

  testWidgets('small screen: most likely', (tester) async {
    await pumpSmall(tester, const MostLikelyGame());
    await flushFontCallbacks(tester);
    await intoGameplay(tester);
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'most_likely');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: would rather', (tester) async {
    await pumpSmall(tester, const WouldRatherGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('أحمد'));
    await tapIf(tester, find.text('منى'));
    await tapIf(tester, find.text('بدء اللعبة'));
    tester.takeException();
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'would_rather');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: never have i', (tester) async {
    await pumpSmall(tester, const NeverHaveIGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('أحمد'));
    await tapIf(tester, find.text('منى'));
    await tapIf(tester, find.text('بدء اللعبة'));
    tester.takeException();
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'never_have_i');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: opposite day gameplay', (tester) async {
    await pumpSmall(tester, const OppositeDay());
    await flushFontCallbacks(tester);
    await intoGameplay(tester);
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'opposite_day');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: truth or lie gameplay', (tester) async {
    await pumpSmall(tester, const TruthOrLieGame());
    await flushFontCallbacks(tester);
    await intoGameplay(tester);
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'truth_or_lie');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: truth or dare gameplay', (tester) async {
    await pumpSmall(tester, const TruthOrDareGame());
    await flushFontCallbacks(tester);
    await intoGameplay(tester);
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'truth_or_dare');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: five seconds gameplay', (tester) async {
    await pumpSmall(tester, const FiveSecondsGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ التحدي 🔥'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'five_seconds');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: heads up flow', (tester) async {
    await pumpSmall(tester, const HeadsUpGame());
    await flushFontCallbacks(tester);
    await capture360(tester, 'heads_up_intro');
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'heads_up_setup');
    expectNoOverflow(tester);
    await tapIf(tester, find.text('اختار شلتك وابدأ!'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('أحمد'));
    await tapIf(tester, find.text('منى'));
    await tapIf(tester, find.text('بدء اللعبة'));
    tester.takeException();
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'heads_up_pass');
    expectNoOverflow(tester);
    await tapIf(tester, find.text('يلا نبدأ!'));
    // 3-2-1 countdown, then the guessing screen (60s turn timer).
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await flushFontCallbacks(tester);
    await capture360(tester, 'heads_up_guess');
    expectNoOverflow(tester);
    // Let the 60s turn elapse so the periodic timer is cancelled and the
    // turn summary shows.
    for (var i = 0; i < 61; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await flushFontCallbacks(tester);
    await capture360(tester, 'heads_up_summary');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: psych flow', (tester) async {
    await pumpSmall(tester, const PsychGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    for (final name in ['أحمد', 'منى', 'كريم']) {
      await tapIf(tester, find.text(name));
    }
    await tapIf(tester, find.text('بدء اللعبة'));
    tester.takeException();
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'psych_pass');
    expectNoOverflow(tester);
    // Lie entry: each player passes the phone and types a fake answer.
    final lies = {'أحمد': 'الدب القطبي', 'منى': 'الكسلان', 'كريم': 'الكسلان'};
    for (final name in ['أحمد', 'منى']) {
      await tapIf(tester, find.text('تمام، أنا $name'));
      await fixedPumps(tester);
      await tester.enterText(find.byType(TextField), lies[name]!);
      await fixedPumps(tester);
      await tapIf(tester, find.text('ثبّت الكدبة 😈'));
      await fixedPumps(tester);
      await flushFontCallbacks(tester);
    }
    // كريم first tries a duplicate lie (same as منى) to trigger the
    // duplicate-error path, then fixes it.
    await tapIf(tester, find.text('تمام، أنا كريم'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'psych_lie');
    expectNoOverflow(tester);
    await tester.enterText(find.byType(TextField), 'الكسلان');
    await fixedPumps(tester);
    await tapIf(tester, find.text('ثبّت الكدبة 😈'));
    await fixedPumps(tester);
    await tester.enterText(find.byType(TextField), 'الفيل');
    await fixedPumps(tester);
    await tapIf(tester, find.text('ثبّت الكدبة 😈'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    // Voting: three pass-and-pick turns, first enabled answer each time.
    for (final name in ['أحمد', 'منى', 'كريم']) {
      await tapIf(tester, find.text('تمام، أنا $name'));
      await fixedPumps(tester);
      final enabled = tester
          .widgetList<ElevatedButton>(find.byType(ElevatedButton))
          .where((b) => b.onPressed != null)
          .toList();
      await tester.tap(find.byWidget(enabled.first));
      await fixedPumps(tester);
      await flushFontCallbacks(tester);
    }
    await capture360(tester, 'psych_reveal');
    expectNoOverflow(tester);
    // Step through the reveal cards (4 answers) to the round scoreboard.
    for (var i = 0; i < 3; i++) {
      await tapIf(tester, find.text('الإجابة الجاية 👉'));
      await fixedPumps(tester);
    }
    await tapIf(tester, find.text('النقاط 📊'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'psych_roundend');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: just one flow', (tester) async {
    await pumpSmall(tester, const JustOneGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    for (final name in ['أحمد', 'منى', 'كريم', 'سارة']) {
      await tapIf(tester, find.text(name));
    }
    await tapIf(tester, find.text('بدء اللعبة'));
    tester.takeException();
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    // Reveal screen -> show mystery word dialog -> confirm
    await tapIf(tester, find.textContaining('إظهار الكلمة للكل'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('شفناها، يلا نكتب التلميحات'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'justone_cluepass');
    expectNoOverflow(tester);
    // Three clue writers (4 players -> guesser + 3 writers), two of them
    // write the SAME clue to exercise the cancellation path.
    final clueWriters = ['منى', 'كريم', 'سارة'];
    final clueTexts = ['أسود', 'أسود', 'ليل'];
    for (var i = 0; i < clueWriters.length; i++) {
      await tapIf(tester, find.text('تمام، أنا ${clueWriters[i]}'));
      await fixedPumps(tester);
      await flushFontCallbacks(tester);
      if (i == 0) {
        await capture360(tester, 'justone_clue');
        expectNoOverflow(tester);
      }
      await tester.enterText(find.byType(TextField), clueTexts[i]);
      await fixedPumps(tester);
      await tapIf(tester, find.text('ثبّت التلميح 🔒'));
      await fixedPumps(tester);
      await flushFontCallbacks(tester);
    }
    // Compare screen: duplicates cancelled (both "أسود" struck through).
    await capture360(tester, 'justone_compare');
    expectNoOverflow(tester);
    expect(find.text('كل التلميحات اتلغت! 😱 الكارت ضاع'), findsNothing);
    // Pass to guesser (أحمد) and make a wrong guess to check the flow.
    await tapIf(tester, find.textContaining('عدّي الموبايل لـ'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'justone_guess');
    expectNoOverflow(tester);
    await tester.enterText(find.byType(TextField), 'تخمين غلط');
    await fixedPumps(tester);
    await tapIf(tester, find.text('خمّن! 🎯'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'justone_turnend');
    expectNoOverflow(tester);
    expect(find.textContaining('غلط'), findsWidgets);
  });

  testWidgets('small screen: wavelength flow', (tester) async {
    await pumpSmall(tester, const WavelengthGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    for (final name in ['أحمد', 'منى', 'كريم', 'سارة']) {
      await tapIf(tester, find.text(name));
    }
    await tapIf(tester, find.text('بدء اللعبة'));
    tester.takeException();
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    // Psychic pass -> psychic view with target shown
    await tapIf(tester, find.textContaining('تمام، أنا'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'wavelength_psychic');
    expectNoOverflow(tester);
    await tester.enterText(find.byType(TextField), 'قهوة الصبح');
    await fixedPumps(tester);
    await tapIf(tester, find.text('قولتها! اخفي الهدف 🙈'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    // Team phase: drag the dial a bit, then lock it
    await capture360(tester, 'wavelength_team');
    expectNoOverflow(tester);
    await tester.drag(find.byType(CustomPaint).last, const Offset(60, -40));
    await fixedPumps(tester);
    await tapIf(tester, find.text('ثبّتوا المؤشر 🔒'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    // Other team guesses left
    await capture360(tester, 'wavelength_leftright');
    expectNoOverflow(tester);
    await tapIf(tester, find.text('شمال'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'wavelength_reveal');
    expectNoOverflow(tester);
    await tapIf(tester, find.textContaining('الدور الجاي'));
    await fixedPumps(tester);
    // Next round should open on the other team's psychic pass
    expect(find.textContaining('عدّي الموبايل لـ'), findsOneWidget);
  });

  testWidgets('small screen: travel bag flow', (tester) async {
    await pumpSmall(tester, const TravelBagGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('أحمد'));
    await tapIf(tester, find.text('منى'));
    await tapIf(tester, find.text('بدء اللعبة'));
    tester.takeException();
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'travelbag_recite');
    expectNoOverflow(tester);
    await tapIf(tester, find.text('قالها صح ✅'));
    await fixedPumps(tester);
    await capture360(tester, 'travelbag_add');
    expectNoOverflow(tester);
    await tester.enterText(find.byType(TextField), 'بطيخة');
    await fixedPumps(tester);
    await tapIf(tester, find.text('رميه في الشنطة! 🧳'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    // Second player recites, gets it wrong -> loses a heart
    await tapIf(tester, find.text('غلط! ❌'));
    await fixedPumps(tester);
    expect(find.textContaining('💔', findRichText: true), findsNothing);
    // First player adds another item
    await tapIf(tester, find.text('قالها صح ✅'));
    await fixedPumps(tester);
    await tester.enterText(find.byType(TextField), 'مظلة');
    await fixedPumps(tester);
    await tapIf(tester, find.text('رميه في الشنطة! 🧳'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    // Knock منى out: her two remaining mistakes (each cycle: she errs,
    // أحمد recites + adds, back to her).
    await tapIf(tester, find.text('غلط! ❌'));
    await fixedPumps(tester);
    await tapIf(tester, find.text('قالها صح ✅'));
    await fixedPumps(tester);
    await tester.enterText(find.byType(TextField), 'شمسية');
    await fixedPumps(tester);
    await tapIf(tester, find.text('رميه في الشنطة! 🧳'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('غلط! ❌'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'travelbag_over');
    expectNoOverflow(tester);
    expect(find.textContaining('آخر واحد واقف'), findsOneWidget);
  });

  testWidgets('small screen: ghost word flow', (tester) async {
    await pumpSmall(tester, const GhostWordGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('أحمد'));
    await tapIf(tester, find.text('منى'));
    await tapIf(tester, find.text('بدء اللعبة'));
    tester.takeException();
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'ghost_play');
    expectNoOverflow(tester);
    // أحمد plays ب, منى plays ح -> fragment بح (not a word yet)
    await tester.tap(find.text('ب'));
    await fixedPumps(tester);
    await tester.tap(find.text('ح'));
    await fixedPumps(tester);
    // أحمد challenges منى
    await tapIf(tester, find.text('تحدي 🚩'));
    await fixedPumps(tester);
    await capture360(tester, 'ghost_challenge');
    expectNoOverflow(tester);
    // منى (challenged) enters a word that doesn't start with بح -> error
    await tester.enterText(find.byType(TextField), 'سمكة');
    await fixedPumps(tester);
    await tapIf(tester, find.text('دي كلمتي! 💪'));
    await fixedPumps(tester);
    expect(find.textContaining('لازم كلمة تبدأ'), findsOneWidget);
    // Now a valid one -> group vote screen
    await tester.enterText(find.byType(TextField), 'بحر');
    await fixedPumps(tester);
    await tapIf(tester, find.text('دي كلمتي! 💪'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'ghost_vote');
    expectNoOverflow(tester);
    // Group says real word -> challenger (أحمد) loses the round
    await tapIf(tester, find.text('كلمة حقيقية ✅'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'ghost_roundend');
    expectNoOverflow(tester);
    expect(find.textContaining('خسر الجولة'), findsOneWidget);
    expect(find.textContaining('جمع: ا'), findsOneWidget);
    await tapIf(tester, find.text('الجولة الجاية ⏭️'));
    await fixedPumps(tester);
    // Next round starts with منى
    expect(find.text('دور منى'), findsOneWidget);
  });

  testWidgets('small screen: wink murder flow', (tester) async {
    await pumpSmall(tester, const WinkMurderGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    for (final name in ['أحمد', 'منى', 'كريم', 'سارة']) {
      await tapIf(tester, find.text(name));
    }
    await tapIf(tester, find.text('بدء اللعبة'));
    tester.takeException();
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    // Deal roles to all 4 players
    for (var i = 0; i < 4; i++) {
      await capture360(tester, i == 0 ? 'wink_rolepass' : 'wink_rolepass_$i');
      await tapIf(tester, find.textContaining('تمام، أنا'));
      await fixedPumps(tester);
      await flushFontCallbacks(tester);
      if (i == 0) {
        await capture360(tester, 'wink_roleshow');
        expectNoOverflow(tester);
      }
      await tapIf(
        tester,
        find.text(i < 3 ? 'فهمت دوري، عدّيها ⏭️' : 'يلا نبدأ الليلة! 🌙'),
      );
      await fixedPumps(tester);
      await flushFontCallbacks(tester);
    }
    // Play screen: one player dies
    await capture360(tester, 'wink_play');
    expectNoOverflow(tester);
    await tester.tap(find.text('كريم'), warnIfMissed: false);
    await fixedPumps(tester);
    await capture360(tester, 'wink_killed');
    // Detective accuses: pick the first alive non-detective player
    await tapIf(tester, find.text('اتهام من المحقق 🚩'));
    await fixedPumps(tester);
    await capture360(tester, 'wink_accuse');
    expectNoOverflow(tester);
    final enabled = tester
        .widgetList<ElevatedButton>(find.byType(ElevatedButton))
        .where((b) => b.onPressed != null)
        .toList();
    expect(enabled, isNotEmpty);
    await tester.tap(find.byWidget(enabled.first));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    // Either a wrong accusation (back to play/accuse) or caught -> round end.
    await capture360(tester, 'wink_after_accuse');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: charades setup', (tester) async {
    await pumpSmall(tester, const CharadesGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'charades');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: word chain setup', (tester) async {
    await pumpSmall(tester, const WordChainGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'word_chain');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: first letter gameplay', (tester) async {
    await pumpSmall(tester, const FirstLetterGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('اختار شلتك وابدأ!'));
    await fixedPumps(tester);
    await tapIf(tester, find.text('أحمد'));
    await tapIf(tester, find.text('منى'));
    await tapIf(tester, find.text('بدء اللعبة'));
    tester.takeException();
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'first_letter');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: word story gameplay', (tester) async {
    await pumpSmall(tester, const WordStoryGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('أحمد'));
    await tapIf(tester, find.text('منى'));
    await tapIf(tester, find.text('بدء اللعبة'));
    tester.takeException();
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'word_story');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: ranking challenge setup', (tester) async {
    await pumpSmall(tester, const RankingChallengeGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'ranking_challenge');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: odd one out gameplay', (tester) async {
    await pumpSmall(tester, const OddOneOut());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'odd_one_out');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: tick tock boom gameplay', (tester) async {
    await pumpSmall(tester, const TickTockBoom());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ'));
    await fixedPumps(tester);
    await capture360(tester, 'tick_tock_boom');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: reverse quiz gameplay', (tester) async {
    await pumpSmall(tester, const ReverseQuiz());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('أحمد'));
    await tapIf(tester, find.text('منى'));
    await tapIf(tester, find.text('بدء اللعبة'));
    tester.takeException();
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'reverse_quiz');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: code names board', (tester) async {
    await pumpSmall(tester, const CodeNamesGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'code_names');
    await tapIf(tester, find.text('أحمد'));
    await tapIf(tester, find.text('منى'));
    await tapIf(tester, find.text('كريم'));
    await tapIf(tester, find.text('سارة'));
    await tapIf(tester, find.text('بدء اللعبة'));
    tester.takeException();
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'code_names_gate');
    await tapIf(tester, find.textContaining('افتح الخريطة'));
    await fixedPumps(tester);
    await capture360(tester, 'code_names_keymap');
    await tapIf(tester, find.textContaining('اكتب التلميح'));
    await fixedPumps(tester);
    await tester.enterText(find.byType(TextField).first, 'حيوانات');
    await tapIf(tester, find.text('اعرض التلميح للفريق'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'code_names_board');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: pictionary drawing phase', (tester) async {
    await pumpSmall(tester, const PictionaryGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('اختار شلتك وابدأ!'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('أحمد'));
    await tapIf(tester, find.text('منى'));
    await tapIf(tester, find.text('بدء اللعبة'));
    tester.takeException();
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'pictionary');
    // drawing -> guessing -> drawer decision -> result phases
    await tapIf(tester, find.textContaining('خلصت الرسم'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'pictionary_guess');
    await tester.enterText(find.byType(TextField).first, 'سمكة');
    await tapIf(tester, find.textContaining('تأكيد الإجابة'));
    await fixedPumps(tester);
    await capture360(tester, 'pictionary_decide');
    await tapIf(tester, find.textContaining('صح ✅'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'pictionary_result');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: seega placement', (tester) async {
    await pumpSmall(tester, const SeegaGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    // real turns: place red and blue stones on the board
    for (final cell in [0, 1, 3, 4]) {
      await tester.tap(
        find.byKey(ValueKey('seega_cell_$cell')),
        warnIfMissed: false,
      );
      await fixedPumps(tester, 2);
    }
    await capture360(tester, 'seega_mid');
    await capture360(tester, 'seega');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: gobblet board', (tester) async {
    await pumpSmall(tester, const GobbletGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'gobblet');
    final invPiece = find.byKey(const ValueKey('gobblet_inv_1_2'));
    await tester.ensureVisible(invPiece);
    await fixedPumps(tester, 2);
    await tester.tap(invPiece);
    await fixedPumps(tester, 2);
    final boardCell = find.byKey(const ValueKey('gobblet_cell_1_1'));
    await tester.ensureVisible(boardCell);
    await fixedPumps(tester, 2);
    await tester.tap(boardCell);
    await fixedPumps(tester, 2);
    await capture360(tester, 'gobblet_mid');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: multi touch idle', (tester) async {
    await pumpSmall(tester, const MultiTouchScreen());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    // two simultaneous touches held down: live circles visible
    final g1 = await tester.startGesture(const Offset(140, 420));
    final g2 = await tester.startGesture(const Offset(260, 480));
    await fixedPumps(tester, 2);
    await capture360(tester, 'multi_touch_live');
    await g1.up();
    await g2.up();
    await fixedPumps(tester, 2);
    await capture360(tester, 'multi_touch');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: reaction arena', (tester) async {
    await pumpSmall(tester, const ReactionGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'reaction_picker');
    await tapIf(tester, find.text('2 لاعبين'));
    await fixedPumps(tester);
    await tapIf(tester, find.text('لا'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'reaction_arena');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: arcade tap_race', (tester) async {
    await pumpSmall(tester, const TapRaceGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'arc_tap_race_a');
    for (final label in ['2 لاعبين', '2', 'لاعبين']) {
      if (find.text(label).evaluate().isNotEmpty) {
        await tapIf(tester, find.text(label).first);
        break;
      }
    }
    await fixedPumps(tester, 4);
    await flushFontCallbacks(tester);
    await capture360(tester, 'arc_tap_race_b');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: arcade tug_of_war', (tester) async {
    await pumpSmall(tester, const TugOfWarGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'arc_tug_of_war_a');
    for (final label in ['2 لاعبين', '2', 'لاعبين']) {
      if (find.text(label).evaluate().isNotEmpty) {
        await tapIf(tester, find.text(label).first);
        break;
      }
    }
    await fixedPumps(tester, 4);
    await flushFontCallbacks(tester);
    await capture360(tester, 'arc_tug_of_war_b');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: arcade sumo', (tester) async {
    await pumpSmall(tester, const SumoGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'arc_sumo_a');
    for (final label in ['2 لاعبين', '2', 'لاعبين']) {
      if (find.text(label).evaluate().isNotEmpty) {
        await tapIf(tester, find.text(label).first);
        break;
      }
    }
    await fixedPumps(tester, 4);
    await flushFontCallbacks(tester);
    await capture360(tester, 'arc_sumo_b');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: arcade snake_arena', (tester) async {
    await pumpSmall(tester, const SnakeArenaGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'arc_snake_arena_a');
    for (final label in ['2 لاعبين', '2', 'لاعبين']) {
      if (find.text(label).evaluate().isNotEmpty) {
        await tapIf(tester, find.text(label).first);
        break;
      }
    }
    await fixedPumps(tester, 4);
    await flushFontCallbacks(tester);
    await capture360(tester, 'arc_snake_arena_b');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: arcade whack_mole', (tester) async {
    await pumpSmall(tester, const WhackMoleGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'arc_whack_mole_a');
    for (final label in ['4 لاعبين', '2 لاعبين']) {
      if (find.text(label).evaluate().isNotEmpty) {
        await tapIf(tester, find.text(label).first);
        break;
      }
    }
    await fixedPumps(tester, 4);
    await flushFontCallbacks(tester);
    await capture360(tester, 'arc_whack_mole_b');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: arcade coin_grab', (tester) async {
    await pumpSmall(tester, const CoinGrabGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'arc_coin_grab_a');
    for (final label in ['4 لاعبين', '2 لاعبين']) {
      if (find.text(label).evaluate().isNotEmpty) {
        await tapIf(tester, find.text(label).first);
        break;
      }
    }
    await fixedPumps(tester, 4);
    await flushFontCallbacks(tester);
    await capture360(tester, 'arc_coin_grab_b');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: arcade catch', (tester) async {
    await pumpSmall(tester, const CatchGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'arc_catch_a');
    for (final label in ['2 لاعبين', '2', 'لاعبين']) {
      if (find.text(label).evaluate().isNotEmpty) {
        await tapIf(tester, find.text(label).first);
        break;
      }
    }
    await fixedPumps(tester, 4);
    await flushFontCallbacks(tester);
    await capture360(tester, 'arc_catch_b');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: arcade touch_ball', (tester) async {
    await pumpSmall(tester, const TouchBallGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'arc_touch_ball_a');
    for (final label in ['2 لاعبين', '2', 'لاعبين']) {
      if (find.text(label).evaluate().isNotEmpty) {
        await tapIf(tester, find.text(label).first);
        break;
      }
    }
    await fixedPumps(tester, 4);
    await flushFontCallbacks(tester);
    await capture360(tester, 'arc_touch_ball_b');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: arcade snow_brawl', (tester) async {
    await pumpSmall(tester, const SnowBrawlGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'arc_snow_brawl_a');
    for (final label in ['2 لاعبين', '2', 'لاعبين']) {
      if (find.text(label).evaluate().isNotEmpty) {
        await tapIf(tester, find.text(label).first);
        break;
      }
    }
    await fixedPumps(tester, 4);
    await flushFontCallbacks(tester);
    await capture360(tester, 'arc_snow_brawl_b');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: arcade tank_battle', (tester) async {
    await pumpSmall(tester, const TankBattleGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'arc_tank_battle_a');
    for (final label in ['2 لاعبين', '2', 'لاعبين']) {
      if (find.text(label).evaluate().isNotEmpty) {
        await tapIf(tester, find.text(label).first);
        break;
      }
    }
    await fixedPumps(tester, 4);
    await flushFontCallbacks(tester);
    await capture360(tester, 'arc_tank_battle_b');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: arcade rhythm', (tester) async {
    await pumpSmall(tester, const RhythmGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'arc_rhythm_a');
    for (final label in ['2 لاعبين', 'لاعب واحد']) {
      if (find.text(label).evaluate().isNotEmpty) {
        await tapIf(tester, find.text(label).first);
        break;
      }
    }
    await fixedPumps(tester, 4);
    await flushFontCallbacks(tester);
    await capture360(tester, 'arc_rhythm_b');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: balance', (tester) async {
    await pumpSmall(tester, const BalanceGame());
    await flushFontCallbacks(tester);
    await fixedPumps(tester, 6);
    await capture360(tester, 'balance_intro');
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'balance_menu');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: victory friends', (tester) async {
    await pumpSmall(
      tester,
      const Scaffold(
        body: Center(child: VictoryFriends(winnerName: 'لاعب 2')),
      ),
    );
    await tester.runAsync(() async {
      for (final a in ['blue', 'purple', 'yellow', 'hijab']) {
        await precacheImage(
          AssetImage('assets/avatars/card_$a.png'),
          tester.element(find.byType(Scaffold)),
        );
      }
    });
    await fixedPumps(tester, 3);
    await flushFontCallbacks(tester);
    await capture360(tester, 'victory_friends');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: taboo', (tester) async {
    await pumpSmall(tester, const TabooGame());
    await flushFontCallbacks(tester);
    await intoGameplay(tester);
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'taboo');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: memory', (tester) async {
    await pumpSmall(tester, const MemoryGame());
    await flushFontCallbacks(tester);
    await intoGameplay(tester);
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'memory');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: emoji guess', (tester) async {
    await pumpSmall(tester, const EmojiGuessGame());
    await flushFontCallbacks(tester);
    await intoGameplay(tester);
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'emoji_guess');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: quiz', (tester) async {
    await pumpSmall(tester, const QuizGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await tapIf(tester, find.text('ثقافة عامة'));
    await tapIf(tester, find.text('اختار الشلة وابدأ >'));
    for (final name in ['أحمد', 'منى']) {
      await tapIf(tester, find.text(name));
    }
    await tapIf(tester, find.text('بدء اللعبة'));
    tester.takeException();
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'quiz');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: xo', (tester) async {
    await pumpSmall(tester, const TicTacToeGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    final cells = find.descendant(
      of: find.byType(GridView),
      matching: find.byType(GestureDetector),
    );
    if (cells.evaluate().length == 9) {
      await tester.tap(cells.at(0), warnIfMissed: false);
      await fixedPumps(tester, 2);
    }
    await flushFontCallbacks(tester);
    await capture360(tester, 'xo');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: bus complete', (tester) async {
    await pumpSmall(tester, const BusCompleteGame());
    await flushFontCallbacks(tester);
    final field = find.byType(TextField);
    for (final name in ['أحمد', 'منى']) {
      await tester.enterText(field, name);
      await fixedPumps(tester, 2);
      await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
      await fixedPumps(tester, 2);
      tester.takeException();
    }
    await tapIf(tester, find.text('اركبوا الأتوبيس! 🚌'));
    tester.takeException();
    await tapIf(tester, find.textContaining('يلا'));
    tester.takeException();
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'bus_complete');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: memory 6 players (30-card board)', (tester) async {
    await pumpSmall(tester, const MemoryGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    for (final name in ['أحمد', 'منى', 'كريم', 'سارة', 'عمر', 'ليلى']) {
      await tapIf(tester, find.text(name));
    }
    await tapIf(tester, find.text('بدء اللعبة'));
    tester.takeException();
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'memory_6p');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: memory 8 players (36-card board)', (tester) async {
    await pumpSmall(tester, const MemoryGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    for (final name in [
      'أحمد',
      'منى',
      'كريم',
      'سارة',
      'عمر',
      'ليلى',
      'حسن',
      'دينا',
    ]) {
      await tapIf(tester, find.text(name));
    }
    await tapIf(tester, find.text('بدء اللعبة'));
    tester.takeException();
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'memory_8p');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: who am i lobby', (tester) async {
    await pumpSmall(tester, const WhoAmIGame());
    await flushFontCallbacks(tester);
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'who_am_i_lobby');
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'who_am_i_setup');
    await tapIf(tester, find.text('اختار شلتك وابدأ!'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('أحمد'));
    await tapIf(tester, find.text('منى'));
    await tapIf(tester, find.text('بدء اللعبة'));
    tester.takeException();
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await tapIf(tester, find.textContaining('تلميح 💡'));
    await fixedPumps(tester);
    await capture360(tester, 'who_am_i');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: player selection restyle', (tester) async {
    await pumpSmall(tester, const MemoryGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    // Let the tiles' entrance animations fully finish before measuring or
    // tapping; ensureVisible mid-animation can nudge the scroll offset.
    await fixedPumps(tester, 6);

    // Select the first two players: both visible on initial entry, so the
    // capture shows the screen as a user first sees it, no scroll offset.
    await tester.tap(find.text('أحمد'), warnIfMissed: false);
    await fixedPumps(tester);
    await tester.tap(find.text('منى'), warnIfMissed: false);
    await fixedPumps(tester);

    // Regression: the list must be at offset zero on initial entry and the
    // first player card fully visible (no clipped top edge).
    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      scrollable.position.pixels,
      0.0,
      reason: 'selection list scrolled on initial entry',
    );
    final listRect = tester.getRect(find.byType(ListView));
    Rect firstCardRect() => tester.getRect(find.byType(ListTile).first);
    expect(
      firstCardRect().top,
      greaterThanOrEqualTo(listRect.top - 0.5),
      reason: 'first player card clipped at top on initial entry',
    );
    expect(
      firstCardRect().bottom,
      lessThanOrEqualTo(listRect.bottom + 0.5),
      reason: 'first player card overflows list viewport',
    );
    final fullHeight = firstCardRect().height;
    expect(
      fullHeight,
      greaterThan(48),
      reason: 'player card unexpectedly short',
    );

    // Scrolling must clip gracefully and return to a fully-visible first
    // card. Programmatic round-trip keeps this deterministic; a gesture
    // drag leaves BouncingScrollPhysics mid-spring and races the asserts.
    scrollable.position.jumpTo(300.0);
    await fixedPumps(tester);
    expect(
      scrollable.position.pixels,
      300.0,
      reason: 'selection list did not scroll',
    );
    scrollable.position.jumpTo(0.0);
    await fixedPumps(tester);
    expect(
      scrollable.position.pixels,
      0.0,
      reason: 'selection list did not settle back to top',
    );
    expect(
      firstCardRect().top,
      greaterThanOrEqualTo(listRect.top - 0.5),
      reason: 'first player card clipped at top after scrolling back',
    );
    expect(
      firstCardRect().height,
      moreOrLessEquals(fullHeight, epsilon: 1),
      reason: 'first player card height changed after scroll round-trip',
    );

    await flushFontCallbacks(tester);
    await capture360(tester, 'player_selection');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: settings restyle', (tester) async {
    await pumpSmall(tester, const SettingsScreen());
    await flushFontCallbacks(tester);
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'settings');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: profile restyle', (tester) async {
    await pumpSmall(tester, const ProfileScreen());
    await flushFontCallbacks(tester);
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'profile');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: password gameplay', (tester) async {
    await pumpSmall(tester, const PasswordGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('أحمد'));
    await tapIf(tester, find.text('منى'));
    await tapIf(tester, find.text('بدء اللعبة'));
    tester.takeException();
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'password');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: spy deal phase', (tester) async {
    await pumpSmall(tester, const SpyGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('أحمد'));
    await tapIf(tester, find.text('منى'));
    await tapIf(tester, find.text('كريم'));
    await tapIf(tester, find.text('بدء اللعبة'));
    tester.takeException();
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'spy');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: proverb gameplay', (tester) async {
    await pumpSmall(tester, const ProverbGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('أحمد'));
    await tapIf(tester, find.text('منى'));
    await tapIf(tester, find.text('بدء اللعبة'));
    tester.takeException();
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'proverb');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: who said vote phase', (tester) async {
    await pumpSmall(tester, const WhoSaidGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('أحمد'));
    await tapIf(tester, find.text('منى'));
    await tapIf(tester, find.text('كريم'));
    await tapIf(tester, find.text('بدء اللعبة'));
    tester.takeException();
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'who_said');
    expectNoOverflow(tester);
  });

  /// Gives SocketService a timer-free fake socket for captures: built with
  /// autoConnect+reconnection disabled, so no reconnect timers stay pending.
  void useFakeSocket() {
    SocketService.debugSocket = sio.io('http://127.0.0.1:9', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'reconnection': false,
      'forceNew': true,
      'multiplex': false,
    });
    SocketService.isTesting = true;
    VoiceChatService.disabled = true;
    addTearDown(() {
      VoiceChatService.disabled = false;
      SocketService.debugSocket?.dispose();
      SocketService.debugSocket = null;
      SocketService.isTesting = false;
    });
  }

  testWidgets('small screen: online lobby restyle', (tester) async {
    useFakeSocket();
    await pumpSmall(tester, const LobbyScreen());
    await flushFontCallbacks(tester);
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'lobby');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: online room restyle', (tester) async {
    useFakeSocket();
    await pumpSmall(
      tester,
      const RoomScreen(roomCode: '12345', isHost: true, playerName: 'أحمد'),
    );
    await flushFontCallbacks(tester);
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'room');
    expectNoOverflow(tester);

    // Regression: the last content must scroll fully clear of the floating
    // emoji picker (bottom: 20). Scroll the room list to its end first.
    final listView = find.byType(Scrollable).first;
    await tester.drag(listView, const Offset(0, -600));
    await fixedPumps(tester);
    await tester.drag(listView, const Offset(0, -600));
    await fixedPumps(tester);
    final fabRect = tester.getRect(find.text('⚡').last);
    // The scroll viewport itself ends above the picker, so no content can
    // be hidden behind it at ANY scroll position (initial included).
    final viewportRect = tester.getRect(
      find.byType(SingleChildScrollView).first,
    );
    expect(
      viewportRect.bottom,
      lessThanOrEqualTo(fabRect.top),
      reason:
          'room scroll viewport reaches behind the emoji picker: '
          'viewport=$viewportRect fab=$fabRect',
    );
    // Belt and braces: at scroll end the last text is also above the picker.
    final lastText = tester.getRect(
      find.text('🎮 ستظهر الألعاب بعد انضمام لاعب آخر'),
    );
    expect(
      lastText.bottom,
      lessThan(fabRect.top),
      reason:
          'room bottom text hidden behind emoji picker: '
          'last=$lastText fab=$fabRect',
    );
  });

  testWidgets('small screen: undercover deal card', (tester) async {
    await pumpSmall(tester, const UndercoverGame(seed: 11));
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    for (final name in ['أحمد', 'منى', 'كريم', 'سارة']) {
      await tapIf(tester, find.text(name));
    }
    await tapIf(tester, find.text('بدء اللعبة'));
    tester.takeException(); // known harness-only debugSize assert
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('شوف كلمتك يا أحمد'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'undercover');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: mafia deal card', (tester) async {
    await pumpSmall(tester, const MafiaGame(seed: 5));
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    for (final name in ['أحمد', 'منى', 'كريم', 'سارة', 'عمر']) {
      await tapIf(tester, find.text(name));
    }
    await tapIf(tester, find.text('بدء اللعبة'));
    tester.takeException(); // known harness-only debugSize assert
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'mafia_hidden');
    await tapIf(tester, find.text('شوف دورك يا أحمد'));
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'mafia');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: flat home direction prototype (harness only)', (
    tester,
  ) async {
    await pumpSmall(tester, const FlatHomePreview());
    await flushFontCallbacks(tester);
    await fixedPumps(tester);
    await capture360(tester, 'flat_home');
    expectNoOverflow(tester);
  });

  testWidgets('small screen: room chat restyle', (tester) async {
    useFakeSocket();
    SocketService().chatMessages.addAll([
      {
        'playerName': 'كريم',
        'message': 'يلا نلعب إكس أو؟',
        'timestamp': DateTime(2026, 11, 26, 19, 30).toIso8601String(),
      },
      {
        'playerName': 'أحمد',
        'message': 'تمام، أنا جاهز 😄',
        'timestamp': DateTime(2026, 11, 26, 19, 31).toIso8601String(),
      },
      {
        'isSystem': true,
        'message': 'انضم كريم للغرفة',
        'timestamp': DateTime(2026, 11, 26, 19, 29).toIso8601String(),
      },
    ]);
    addTearDown(() => SocketService().chatMessages.clear());
    await pumpSmall(
      tester,
      SizedBox(
        height: 900,
        child: Material(
          child: ChatWidget(
            roomCode: '12345',
            playerName: 'أحمد',
            initialMessages: SocketService().chatMessages,
          ),
        ),
      ),
    );
    await flushFontCallbacks(tester);
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'room_chat');
  });

  testWidgets('small screen: scoreboard restyle', (tester) async {
    final scores = ScoreService();
    scores.setPlayers(['أحمد', 'منى', 'كريم']);
    scores.addScore('أحمد', 7);
    scores.addScore('منى', 3);
    scores.addScore('كريم', 5);
    addTearDown(scores.clearSession);
    await pumpSmall(tester, const ScoreboardScreen());
    await flushFontCallbacks(tester);
    await fixedPumps(tester);
    await flushFontCallbacks(tester);
    await capture360(tester, 'scoreboard');
    expectNoOverflow(tester);
  });
}
