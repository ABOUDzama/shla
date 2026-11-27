import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shella/games/offline/touch_ball_game.dart';
import 'package:shella/services/audio_service.dart';

Future<void> flushFontCallbacks(WidgetTester tester) async {
  await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
  await tester.pump();
}

Future<void> warmGoogleFonts(WidgetTester tester) async {
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Column(children: [
      for (final w in [
        FontWeight.w400, FontWeight.w500, FontWeight.w600,
        FontWeight.w700, FontWeight.w800, FontWeight.w900,
      ])
        Text('warm', style: GoogleFonts.cairo(fontWeight: w)),
    ]),
  ));
  await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
  await tester.pump();
}

Future<void> settleDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump(const Duration(milliseconds: 1));
}

Future<void> boot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await warmGoogleFonts(tester);
  await tester.pumpWidget(const MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: TouchBallGame(randomSeed: 7),
    ),
  ));
  await flushFontCallbacks(tester);
  await tester.tap(find.textContaining('ابدأ اللعبة'));
  await tester.pump();
}

dynamic state(WidgetTester t) => t.state(find.byType(TouchBallGame));

void main() {
  setUp(() => AudioService.mutedForTests = true);
  tearDown(() => AudioService.mutedForTests = false);
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('touch ball: intro leads to picker incl. solo', (tester) async {
    await boot(tester);
    expect(find.text('كام لاعب؟'), findsOneWidget);
    expect(find.text('لاعب واحد'), findsOneWidget);
    expect(find.text('2 لاعبين'), findsOneWidget);
    expect(find.text('3 لاعبين'), findsOneWidget);
    expect(find.text('4 لاعبين'), findsOneWidget);
    await settleDown(tester);
  });

  testWidgets('touch ball: 2p no bots starts with two zones', (tester) async {
    await boot(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump();
    expect(find.text('نضيف بوتات؟'), findsOneWidget);
    await tester.tap(find.text('لا'));
    await tester.pump();
    expect(state(tester).debugMatch.players, 2);
    expect(state(tester).debugBotSeats, isEmpty);
    await settleDown(tester);
  });

  testWidgets('touch ball: bots tap their own balls without help', (tester) async {
    await boot(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump();
    await tester.tap(find.text('اه 🤖'));
    await tester.pump();
    final m = state(tester).debugMatch;
    expect(m.players, 4);
    expect(state(tester).debugBotSeats, {2, 3});
    // run ~60s of fake play; a bot-owned ball comes up and gets bot-tapped
    for (var i = 0; i < 240 && m.scores[2] + m.scores[3] == 0; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(m.scores[2] + m.scores[3], greaterThan(0));
    await settleDown(tester);
  });

  testWidgets('touch ball: 2p wrong-zone tap is penalized (ported from legacy suite)',
      (tester) async {
    await boot(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump();
    await tester.tap(find.text('لا'));
    await tester.pump();
    final ball = find.byKey(const Key('touch_ball'));

    /// Owner index parsed from the round banner 'كورة لاعب N!'.
    int? owner() {
      final f = find.textContaining('كورة لاعب');
      if (f.evaluate().isEmpty) return null;
      final data = (tester.widget(f.first) as Text).data ?? '';
      final m = RegExp(r'كورة لاعب (\d)').firstMatch(data);
      return m == null ? null : int.parse(m.group(1)!) - 1;
    }

    /// In 2p the zones are top/bottom halves (seat 0 = top).
    int ballZone() {
      final stack =
          find.ancestor(of: ball, matching: find.byType(Stack));
      final arena = tester.getRect(stack.first);
      final c = tester.getCenter(ball);
      return c.dy < arena.center.dy ? 0 : 1;
    }

    // The ball spawns in its owner's half but drifts; within a few rounds it
    // must cross into the other half, and a tap there belongs to no owner.
    var tapped = false;
    for (var round = 0; round < 12 && !tapped; round++) {
      var waited = 0;
      while (ball.evaluate().isEmpty && waited < 80) {
        await tester.pump(const Duration(milliseconds: 100));
        waited++;
      }
      var steps = 0;
      while (ball.evaluate().isNotEmpty &&
          (owner() == null || ballZone() == owner()) &&
          steps < 60) {
        await tester.pump(const Duration(milliseconds: 50));
        steps++;
      }
      if (ball.evaluate().isNotEmpty &&
          owner() != null &&
          ballZone() != owner()) {
        await tester.tap(ball);
        await tester.pump();
        tapped = true;
      }
    }
    expect(tapped, isTrue,
        reason: 'a ball must drift out of the owner zone within 12 rounds');
    expect(find.textContaining('لمس كورة مش بتاعته'), findsOneWidget);
    expect((state(tester).debugMatch.scores as List).every((s) => (s as num) <= 0), isTrue);
    await settleDown(tester);
  });

  testWidgets('touch ball: solo practice - every ball is yours, tap to 5', (tester) async {
    await boot(tester);
    await tester.tap(find.text('لاعب واحد'));
    await tester.pump();
    await tester.tap(find.text('لا'));
    await tester.pump();
    final m = state(tester).debugMatch;
    expect(m.players, 1);
    // tap each ball as it appears until practice completes at 5 points
    for (var i = 0; i < 400 && m.matchWinner == null; i++) {
      final ball = find.byKey(const Key('touch_ball'));
      if (ball.evaluate().isNotEmpty) {
        await tester.tap(ball, warnIfMissed: false);
      }
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(m.matchWinner, 0);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('تدريب كامل'), findsOneWidget);
    await settleDown(tester);
  });


  testWidgets('touch ball: 3p no bots starts with three zones', (tester) async {
    await boot(tester);
    await tester.tap(find.text('3 لاعبين'));
    await tester.pump();
    await tester.tap(find.text('لا'));
    await tester.pump();
    final m = state(tester).debugMatch;
    expect(m.players, 3);
    expect(m.scores.length, 3);
    expect(state(tester).debugBotSeats, isEmpty);
    await settleDown(tester);
  });
}
