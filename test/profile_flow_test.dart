import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/widgets/avatar_picker_sheet.dart';
import 'package:shella/services/avatar_service.dart';
import 'package:shella/services/settings_service.dart';
import 'package:shella/screens/welcome_screen.dart';
import 'package:shella/screens/global_player_selection_screen.dart';

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

  Future<void> setup(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(textDirection: TextDirection.rtl, child: w),
    ));
    await tester.runAsync(() async {
      for (final a in [...AvatarService.pickerAvatars, 'assets/avatars_2d/group.jpg']) {
        await precacheImage(AssetImage(a), tester.element(find.byType(Scaffold)));
      }
    });
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('first launch: welcome -> name+avatar -> saved', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.init();
    expect(SettingsService.userName, '');
    var done = false;
    await setup(tester, WelcomeScreen(onDone: () => done = true));
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/profile_welcome.png'));
    await tester.tap(find.text('يلا نبدأ'));
    await tester.pump(const Duration(milliseconds: 400));
    // save disabled until name and avatar chosen
    await tester.tap(find.text('دخول الشلة'));
    await tester.pump();
    expect(done, false);
    await tester.enterText(find.byKey(const ValueKey('profile_name')), 'عبود');
    await tester.tap(find.byKey(ValueKey('pick_${AvatarService.pickerAvatars[2]}')));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/profile_setup.png'));
    await tester.tap(find.text('دخول الشلة'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(done, true);
    expect(SettingsService.userName, 'عبود');
    expect(SettingsService.userAvatar, 'asset:${AvatarService.pickerAvatars[2]}');
  });

  testWidgets('returning user: self auto-added first in game selection', (tester) async {
    SharedPreferences.setMockInitialValues({
      'current_user_name': 'عبود',
      'current_user_avatar': 'asset:${AvatarService.pickerAvatars[2]}',
      'saved_players_roster': [
        '{"name":"عبود","avatar":""}',
        '{"name":"سارة","avatar":"asset:${AvatarService.pickerAvatars[0]}"}',
        '{"name":"كريم","avatar":"asset:${AvatarService.pickerAvatars[4]}"}',
      ],
    });
    await SettingsService.init();
    List<String>? started;
    await setup(tester, GlobalPlayerSelectionScreen(
      gameTitle: 'لعبة', minPlayers: 2, maxPlayers: 4,
      onStartGame: (c, p) => started = p));
    expect(find.byKey(const ValueKey('me_row')), findsOneWidget);
    expect(find.text('عبود'), findsNothing, reason: 'duplicate roster entry of self hidden');
    await tester.pump(const Duration(milliseconds: 800));
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/profile_selection.png'));
    await tester.tap(find.text('بدء اللعبة'));
    await tester.pump();
    expect(started, isNull, reason: 'self alone is below min 2');
    await tester.tap(find.text('سارة'));
    await tester.pump();
    await tester.tap(find.text('بدء اللعبة'));
    await tester.pump();
    expect(started, ['عبود', 'سارة']);
  });
}
