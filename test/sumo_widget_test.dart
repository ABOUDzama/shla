import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shella/games/offline/sumo_game.dart';

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
      child: SumoGame(randomSeed: 7),
    ),
  ));
  await flushFontCallbacks(tester);
  await tester.tap(find.textContaining('ابدأ اللعبة'));
  await tester.pump();
}

dynamic state(WidgetTester t) => t.state(find.byType(SumoGame));

Future<void> fightThroughCountdown(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('sumo: intro leads to player picker incl. solo', (tester) async {
    await boot(tester);
    expect(find.text('كام لاعب؟'), findsOneWidget);
    expect(find.text('لاعب واحد'), findsOneWidget);
    expect(find.text('2 لاعبين'), findsOneWidget);
    expect(find.text('3 لاعبين'), findsOneWidget);
    expect(find.text('4 لاعبين'), findsOneWidget);
    await settleDown(tester);
  });

  testWidgets('sumo: 2p no bots starts 0v1 after countdown', (tester) async {
    await boot(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump();
    expect(find.text('نضيف بوتات؟'), findsOneWidget);
    await tester.tap(find.text('لا'));
    await tester.pump();
    expect(state(tester).debugPair, [0, 1]);
    await fightThroughCountdown(tester);
    expect(find.text('دووووس!'), findsWidgets);
    await settleDown(tester);
  });

  testWidgets('sumo: 2p with bots fills to 4; bot-vs-bot resolves and human meets a bot in the final', (tester) async {
    await boot(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump();
    await tester.tap(find.text('اه 🤖'));
    await tester.pump();
    expect(state(tester).debugPair, [0, 1]);
    await fightThroughCountdown(tester);
    // human seat 0 mashes to a ring-out win (pushStep 0.02 -> 50 taps);
    // zones unmount the moment the match ends, so stop when they vanish
    for (var i = 0; i < 60; i++) {
      final zone = find.byKey(const Key('sumo_zone_0'));
      if (zone.evaluate().isEmpty) break;
      await tester.tap(zone, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 300));
    // match break announces the winner, then the next match starts on tap
    expect(find.textContaining('كسب الماتش'), findsOneWidget);
    await tester.tap(find.text('ابدأ الماتش 💪'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // bot-vs-bot semi resolved instantly; the final pairs a human vs a bot
    final pair = state(tester).debugPair as List<int>;
    expect(pair.toSet().intersection({2, 3}).length, 1);
    await fightThroughCountdown(tester);
    await settleDown(tester);
  });

  testWidgets('sumo: solo practice vs dummy ends with a tap-count result', (tester) async {
    await boot(tester);
    await tester.tap(find.text('لاعب واحد'));
    await tester.pump();
    await tester.tap(find.text('لا'));
    await tester.pump();
    expect(state(tester).debugPair, [0, -1]);
    expect(find.text('دمية تدريب 🎯'), findsOneWidget);
    await fightThroughCountdown(tester);
    for (var i = 0; i < 60; i++) {
      final zone = find.byKey(const Key('sumo_zone_0'));
      if (zone.evaluate().isEmpty) break;
      await tester.tap(zone, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('دوسة'), findsOneWidget);
    await settleDown(tester);
  });


  testWidgets('2p ported: shove-out win then العبوا تاني returns to picker', (tester) async {
    await boot(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('لا'));
    final st = tester.state(find.byType(SumoGame)) as dynamic;
    await fightThroughCountdown(tester);
    final pair = st.debugPair as List<int>;
    expect(pair, [0, 1]);
    for (var i = 0;
        i < 60 && find.byKey(const ValueKey('sumo_zone_0')).evaluate().isNotEmpty;
        i++) {
      await tester.tap(find.byKey(const ValueKey('sumo_zone_0')), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 16));
    }
    // 2p has a single deciding fight: the win goes straight to the over screen
    expect(find.text('العبوا تاني 🤼'), findsOneWidget);
    await tester.tap(find.text('العبوا تاني 🤼'));
    await tester.pump();
    expect(find.text('كام لاعب؟'), findsOneWidget);
    await settleDown(tester);
  });
}
