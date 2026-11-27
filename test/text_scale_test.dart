import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/screens/settings_screen.dart';
import 'package:shella/screens/profile_screen.dart';
import 'package:shella/screens/leaderboard_screen.dart';
import 'package:shella/screens/scoreboard_screen.dart';
import 'package:shella/screens/arcade_section_screen.dart';
import 'package:shella/screens/cup/cup_setup_screen.dart';
import 'package:shella/games/offline/most_likely_game.dart';
import 'package:shella/games/offline/five_seconds_game.dart';
import 'package:shella/services/score_service.dart';
import 'package:shella/services/settings_service.dart';

/// Accessibility pass: the small-screen suite proves 360px layouts at the
/// default text scale. These spot checks pump the most text-dense screens at
/// 1.3x text scale (a common device accessibility setting) and assert no
/// RenderFlex overflow.
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
    final l = FontLoader('Noto Color Emoji')
      ..addFont(Future.value(ByteData.sublistView(emojiBytes)));
    await l.load();
  });

  Future<void> pumpScaled(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamilyFallback: const ['Noto Color Emoji']),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 400)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
  }

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

  testWidgets('settings at 1.3x text scale', (tester) async {
    await pumpScaled(tester, const SettingsScreen());
    expectNoOverflow(tester);
  });

  testWidgets('profile at 1.3x text scale', (tester) async {
    await pumpScaled(tester, const ProfileScreen());
    expectNoOverflow(tester);
  });

  testWidgets('leaderboard at 1.3x text scale', (tester) async {
    await pumpScaled(tester, const LeaderboardScreen());
    expectNoOverflow(tester);
  });

  testWidgets('scoreboard at 1.3x text scale', (tester) async {
    final scores = ScoreService();
    scores.setPlayers(['أحمد', 'منى', 'كريم']);
    scores.addScore('أحمد', 7);
    scores.addScore('منى', 3);
    addTearDown(scores.clearSession);
    await pumpScaled(tester, const ScoreboardScreen());
    expectNoOverflow(tester);
  });

  testWidgets('cup setup at 1.3x text scale', (tester) async {
    await pumpScaled(tester, const CupSetupScreen());
    expectNoOverflow(tester);
  });

  testWidgets('arcade section at 1.3x text scale', (tester) async {
    await pumpScaled(tester, const ArcadeSectionScreen());
    expectNoOverflow(tester);
  });

  testWidgets('most likely gameplay at 1.3x text scale', (tester) async {
    await pumpScaled(tester, const MostLikelyGame());
    // into gameplay: tap through the intro/start button if present
    final start = find.text('ابدأ');
    if (start.evaluate().isNotEmpty) {
      await tester.tap(start.first);
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 120));
    }
    expectNoOverflow(tester);
  });

  testWidgets('five seconds gameplay at 1.3x text scale', (tester) async {
    await pumpScaled(tester, const FiveSecondsGame());
    final start = find.text('ابدأ');
    if (start.evaluate().isNotEmpty) {
      await tester.tap(start.first);
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 120));
    }
    expectNoOverflow(tester);
  });
}
