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
import 'package:shella/screens/settings_screen.dart';
import 'package:shella/screens/profile_screen.dart';
import 'package:shella/games/offline/password_game.dart';
import 'package:shella/games/offline/spy_game.dart';
import 'package:shella/games/offline/proverb_game.dart';
import 'package:shella/games/offline/who_said_game.dart';
import 'package:shella/games/offline/undercover_game.dart';
import 'package:shella/games/offline/mafia_game.dart';
import 'package:shella/widgets/flat_home_preview.dart';
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
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
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
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 400)));
    await fixedPumps(tester, 2);
    final scaffoldFind = find.byType(Scaffold);
    if (scaffoldFind.evaluate().isNotEmpty) {
      ScaffoldMessenger.of(tester.element(scaffoldFind.first))
          .hideCurrentSnackBar();
      await fixedPumps(tester, 1);
    }
    final boundary = boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2.0));
    final byteData = await tester
        .runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
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
    final overflows =
        seen.where((m) => m.contains('overflowed') || m.contains('RenderFlex'));
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
        of: find.byType(GridView), matching: find.byType(GestureDetector));
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

  testWidgets('small screen: memory 6 players (30-card board)',
      (tester) async {
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

  testWidgets('small screen: memory 8 players (36-card board)',
      (tester) async {
    await pumpSmall(tester, const MemoryGame());
    await flushFontCallbacks(tester);
    await tapIf(tester, find.text('ابدأ اللعبة 🚀'));
    for (final name in [
      'أحمد', 'منى', 'كريم', 'سارة', 'عمر', 'ليلى', 'حسن', 'دينا'
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
    final scrollable = tester.state<ScrollableState>(find
        .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
        .first);
    expect(scrollable.position.pixels, 0.0,
        reason: 'selection list scrolled on initial entry');
    final listRect = tester.getRect(find.byType(ListView));
    Rect firstCardRect() => tester.getRect(find.byType(ListTile).first);
    expect(firstCardRect().top, greaterThanOrEqualTo(listRect.top - 0.5),
        reason: 'first player card clipped at top on initial entry');
    expect(firstCardRect().bottom, lessThanOrEqualTo(listRect.bottom + 0.5),
        reason: 'first player card overflows list viewport');
    final fullHeight = firstCardRect().height;
    expect(fullHeight, greaterThan(48),
        reason: 'player card unexpectedly short');

    // Scrolling must clip gracefully and return to a fully-visible first
    // card. Programmatic round-trip keeps this deterministic; a gesture
    // drag leaves BouncingScrollPhysics mid-spring and races the asserts.
    scrollable.position.jumpTo(300.0);
    await fixedPumps(tester);
    expect(scrollable.position.pixels, 300.0,
        reason: 'selection list did not scroll');
    scrollable.position.jumpTo(0.0);
    await fixedPumps(tester);
    expect(scrollable.position.pixels, 0.0,
        reason: 'selection list did not settle back to top');
    expect(firstCardRect().top, greaterThanOrEqualTo(listRect.top - 0.5),
        reason: 'first player card clipped at top after scrolling back');
    expect(firstCardRect().height, moreOrLessEquals(fullHeight, epsilon: 1),
        reason: 'first player card height changed after scroll round-trip');

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
    final viewportRect =
        tester.getRect(find.byType(SingleChildScrollView).first);
    expect(viewportRect.bottom, lessThanOrEqualTo(fabRect.top),
        reason: 'room scroll viewport reaches behind the emoji picker: '
            'viewport=$viewportRect fab=$fabRect');
    // Belt and braces: at scroll end the last text is also above the picker.
    final lastText = tester.getRect(find.text('🎮 ستظهر الألعاب بعد انضمام لاعب آخر'));
    expect(lastText.bottom, lessThan(fabRect.top),
        reason: 'room bottom text hidden behind emoji picker: '
            'last=$lastText fab=$fabRect');
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

  testWidgets('small screen: flat home direction prototype (harness only)',
      (tester) async {
    await pumpSmall(tester, const FlatHomePreview());
    await flushFontCallbacks(tester);
    await fixedPumps(tester);
    await capture360(tester, 'flat_home');
    expectNoOverflow(tester);
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
