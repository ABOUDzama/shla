import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/games/offline/chicken_run_game.dart';
import 'package:shella/games/offline/chicken_run_logic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final emojiBytes = await File('test/fonts_NotoColorEmoji.ttf').readAsBytes();
    final l = FontLoader('Noto Color Emoji')..addFont(Future.value(ByteData.sublistView(emojiBytes)));
    await l.load();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(textDirection: TextDirection.rtl, child: ChickenRunGame(randomSeed: 3)),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await tester.pump();
    await tester.ensureVisible(find.text('ابدأ اللعبة 🚀'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('ابدأ اللعبة 🚀'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 600)));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  }

  ChickenRunMatch m(WidgetTester t) =>
      (t.state(find.byType(ChickenRunGame)) as dynamic).debugMatch as ChickenRunMatch;

  testWidgets('4 players: each corner pad flips only its own chicken', (tester) async {
    await open(tester);
    await tester.tap(find.text('4 لاعبين'));
    await tester.pump(const Duration(milliseconds: 100));
    final match = m(tester);
    expect(match.seats, 4);
    expect(match.botSeats, isEmpty);
    for (final s in [0, 1, 2, 3]) {
      expect(find.byKey(ValueKey('pad_$s')), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('pad_2')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(match.flightLeft[2], greaterThan(0), reason: 'seat 3 started a flip');
    expect(match.flightLeft[0], 0);
    expect(match.flightLeft[1], 0);
    await tester.pump(const Duration(milliseconds: 400));
    expect(match.surface[2], 1, reason: 'landed on the ceiling');
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/chicken_run_play.png'));
    await tester.pump(const Duration(seconds: 12));
    await settle(tester);
  });

  testWidgets('bots rule: 2 players "لا" has no bots; "اه" fills to 4', (tester) async {
    await open(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(m(tester).seats, 2);
    expect(m(tester).botSeats, isEmpty);
    await tester.pump(const Duration(seconds: 12));
    await settle(tester);
  });

  testWidgets('bots "اه": humans 2 + 2 bots', (tester) async {
    await open(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('اه 🤖'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(m(tester).seats, 4);
    expect(m(tester).botSeats, {2, 3});
    await tester.pump(const Duration(seconds: 12));
    await settle(tester);
  });

  testWidgets('practice: 1 player "لا" runs alone, ends on falling, no result', (tester) async {
    await open(tester);
    await tester.tap(find.text('لاعب واحد'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('لا'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(m(tester).seats, 1);
    // never press: the chicken eventually stands on a floor hole
    for (var i = 0; i < 400 && find.textContaining('وقعت بعد').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('وقعت بعد'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/chicken_run_over.png'));
    await settle(tester);
  });
}
