import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/widgets/avatar_picker_sheet.dart';
import 'package:shella/services/avatar_service.dart';
import 'package:shella/services/settings_service.dart';
import 'package:shella/services/results_service.dart';
import 'package:shella/screens/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    for (final name in [
      'Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black'
    ]) {
      final bytes = await File('assets/fonts/Cairo-$name.ttf').readAsBytes();
      final loader = FontLoader('Cairo')
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
    final icons = await File(
      Platform.environment['HOME']! +
          '/sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytes();
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons)));
    await iconLoader.load();
    final emojiBytes =
        await File('test/fonts_NotoColorEmoji.ttf').readAsBytes();
    final emojiLoader = FontLoader('Noto Color Emoji')
      ..addFont(Future.value(ByteData.sublistView(emojiBytes)));
    await emojiLoader.load();
  });

  testWidgets('home: الترتيب tab shows podium + recent after real wins', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'current_user_name': 'عبود',
      'current_user_avatar': 'asset:${AvatarService.pickerAvatars[2]}',
      'saved_players_roster': [
        '{"name":"سارة","avatar":"asset:${AvatarService.pickerAvatars[0]}"}',
      ],
    });
    await SettingsService.init();
    await tester.runAsync(() async {
      final s = ResultsService.instance;
      final t = DateTime.now();
      await s.recordWin(game: 'إكس أو', winner: 'عبود', now: t.subtract(const Duration(minutes: 9)));
      await s.recordWin(game: 'سيجا', winner: 'سارة', now: t.subtract(const Duration(minutes: 5)));
      await s.recordWin(game: 'جوبلت', winner: 'عبود', now: t.subtract(const Duration(minutes: 2)));
      await s.recordWin(game: 'سومو الشلة', winner: 'لاعب 2', now: t);
    });
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(textDirection: TextDirection.rtl, child: const HomeScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('الترتيب'));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.runAsync(() async {
      for (final a in AvatarService.pickerAvatars) {
        await precacheImage(AssetImage(a), tester.element(find.byType(HomeScreen)));
      }
    });
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('rank_0')), findsOneWidget);
    expect(find.text('2 فوز'), findsWidgets);
    expect(find.textContaining('لاعب 2'), findsOneWidget, reason: 'seat win only in recent list');
    await expectLater(find.byType(HomeScreen), matchesGoldenFile('goldens/leaderboard_home.png'));
  });
}
