import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shella/games/offline/rhythm_game.dart';
import 'package:shella/games/offline/rhythm_logic.dart';
import 'package:shella/services/audio_service.dart';
import 'package:shella/games/offline/rhythm_mic.dart';
import 'package:shella/widgets/victory_friends.dart';

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

class FakeClapDetector extends ClapDetector {
  FakeClapDetector(this.available);
  final bool available;
  bool started = false;
  bool stopped = false;

  @override
  Future<bool> start() async {
    if (!available) return false;
    started = true;
    return true;
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }

  void clap() => onClap?.call();
}

/// Manual clock the test advances alongside tester.pump.
class ManualClock {
  int t = 0;
  int now() => t;
}

Future<({ManualClock clock, FakeClapDetector mic})> boot(
  WidgetTester tester, {
  int maxLevels = 1,
  bool micAvailable = true,
  bool skipStart = false,
}) async {
  tester.view.physicalSize = const Size(412, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await warmGoogleFonts(tester);
  final clock = ManualClock();
  final mic = FakeClapDetector(micAvailable);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(fontFamilyFallback: const ['Noto Color Emoji']),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: RhythmGame(
        randomSeed: 7,
        maxLevels: maxLevels,
        nowMs: clock.now,
        micDetectorFactory: () => mic,
      ),
    ),
  ));
  await flushFontCallbacks(tester);
  if (!skipStart) {
    await tester.tap(find.textContaining('ابدأ اللعبة'));
    await tester.pump();
  }
  return (clock: clock, mic: mic);
}

/// Runs one full turn in tap mode, tapping the pad at the pattern's exact
/// onsets. Advances the manual clock in lockstep with pumped time.
Future<void> playPerfectTurn(
    WidgetTester tester, ManualClock clock, List<int> onsets) async {
  await tester.tap(find.text('يلا ▶'));
  // watching: pattern + 1200ms outro
  final watchMs = (onsets.last) + 1200;
  clock.t += watchMs;
  await tester.pump(Duration(milliseconds: watchMs));
  await tester.pump();
  // listening: tap each onset on the clock
  var prev = 0;
  for (final o in onsets) {
    final step = o - prev;
    clock.t += step;
    await tester.pump(Duration(milliseconds: step));
    await tester.tap(find.byKey(const Key('rhythm_tap_pad')));
    await tester.pump();
    prev = o;
  }
  // let the listen window expire
  final rest = 1500 - 0;
  clock.t += rest;
  await tester.pump(Duration(milliseconds: rest));
  await tester.pump();
}

/// The game's own generator (seed 7) produces this exact first pattern.
final level1Onsets = RhythmGenerator(seed: 7).next(1).onsetsMs;

void main() {
  setUp(() => AudioService.mutedForTests = true);
  tearDown(() => AudioService.mutedForTests = false);

  testWidgets('intro explains clap and tap modes', (tester) async {
    await boot(tester, skipStart: true);
    expect(find.textContaining('إيقاع تصفيق'), findsWidgets);
    expect(find.textContaining('المايك'), findsWidgets);
    expect(find.textContaining('وضع تجريبي'), findsWidgets);
    await settleDown(tester);
  });

  testWidgets('tap mode: perfect turn passes and winner is crowned',
      (tester) async {
    final env = await boot(tester);
    await tester.tap(find.text('2 لاعبين'));
    await tester.pump();
    expect(find.text('هتقلّدوا الإيقاع إزاي؟'), findsOneWidget);
    expect(find.text('تصفيق 👏 (تجريبي)'), findsOneWidget);
    await tester.tap(find.text('دوس على الزرار 👆'));
    await tester.pump();
    // level 1, player 1 turn: seed 7 level-1 pattern has 4 claps
    expect(find.text('دور لاعب 1'), findsOneWidget);
    await playPerfectTurn(tester, env.clock, level1Onsets);
    expect(find.textContaining('%'), findsOneWidget);
    await tester.tap(find.text('تمام'));
    await tester.pump();
    // player 2: also perfect -> tie at the top -> no crown, 'تعادل'
    expect(find.text('دور لاعب 2'), findsOneWidget);
    await playPerfectTurn(tester, env.clock, level1Onsets);
    await tester.tap(find.text('تمام'));
    await tester.pump();
    // level result -> final (maxLevels = 1)
    expect(find.text('النتيجة النهائية 🏁'), findsOneWidget);
    await tester.tap(find.text('النتيجة النهائية 🏁'));
    await tester.pump();
    expect(find.text('تعادل! 🤝'), findsOneWidget);
    expect(find.byType(VictoryFriends), findsNothing);
    await settleDown(tester);
  });

  testWidgets('a missed pattern fails the turn', (tester) async {
    final env = await boot(tester);
    await tester.tap(find.text('لاعب واحد'));
    await tester.pump();
    await tester.tap(find.text('دوس على الزرار 👆'));
    await tester.pump();
    expect(find.text('دور لاعب 1'), findsOneWidget);
    // watch, then tap nothing: let the listen window expire
    await tester.tap(find.text('يلا ▶'));
    final watchMs = level1Onsets.last + 1200;
    env.clock.t += watchMs;
    await tester.pump(Duration(milliseconds: watchMs));
    await tester.pump();
    final idle = level1Onsets.last + 1600;
    env.clock.t += idle;
    await tester.pump(Duration(milliseconds: idle));
    await tester.pump();
    expect(find.textContaining('لسه..'), findsOneWidget);
    await tester.tap(find.text('تمام'));
    await tester.pump();
    // solo = practice: final screen has no winner flow
    await tester.tap(find.text('النتيجة النهائية 🏁'));
    await tester.pump();
    expect(find.textContaining('انتهى التدريب'), findsOneWidget);
    expect(find.byType(VictoryFriends), findsNothing);
    await settleDown(tester);
  });

  testWidgets('mic mode: detector used; honest fallback when unavailable',
      (tester) async {
    final env = await boot(tester);
    await tester.tap(find.text('لاعب واحد'));
    await tester.pump();
    await tester.tap(find.text('تصفيق 👏 (تجريبي)'));
    await tester.pump();
    expect(find.text('دور لاعب 1'), findsOneWidget);
    await tester.tap(find.text('يلا ▶'));
    final watchMs = level1Onsets.last + 1200;
    env.clock.t += watchMs;
    await tester.pump(Duration(milliseconds: watchMs));
    await tester.pump();
    await tester.pump();
    // mic detector started and drives onsets
    expect(env.mic.started, isTrue);
    expect(find.text('👏'), findsOneWidget);
    env.clock.t += 100;
    await tester.pump(const Duration(milliseconds: 100));
    env.mic.clap();
    await tester.pump();
    final idle = level1Onsets.last + 1600;
    env.clock.t += idle;
    await tester.pump(Duration(milliseconds: idle));
    await tester.pump();
    expect(env.mic.stopped, isTrue);
    await settleDown(tester);
  });

  testWidgets('mic unavailable: truthful banner and tap pad fallback',
      (tester) async {
    final env = await boot(tester, micAvailable: false);
    await tester.tap(find.text('لاعب واحد'));
    await tester.pump();
    await tester.tap(find.text('تصفيق 👏 (تجريبي)'));
    await tester.pump();
    await tester.tap(find.text('يلا ▶'));
    final watchMs = level1Onsets.last + 1200;
    env.clock.t += watchMs;
    await tester.pump(Duration(milliseconds: watchMs));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('المايك مش متاح'), findsOneWidget);
    expect(find.byKey(const Key('rhythm_tap_pad')), findsOneWidget);
    await settleDown(tester);
  });
}
