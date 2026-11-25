import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/screens/shellty_screen.dart';
import 'package:shella/services/avatar_service.dart';
import 'package:shella/services/settings_service.dart';

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

  testWidgets('شلتي tab renders roster with built-in avatars', (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'sound_enabled': false});
    await SettingsService.init();
    await SettingsService.savePlayersProfiles([
      {
        'name': 'مونا',
        'avatar':
            '${AvatarService.assetPrefix}${AvatarService.builtInAvatars[0]}'
      },
      {
        'name': 'كريم',
        'avatar':
            '${AvatarService.assetPrefix}${AvatarService.builtInAvatars[1]}'
      },
      {
        'name': 'حسن',
        'avatar':
            '${AvatarService.assetPrefix}${AvatarService.builtInAvatars[2]}'
      },
      {'name': 'سارة', 'avatar': ''},
    ]);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamilyFallback: const ['Noto Color Emoji']),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: ShelltyScreen(),
        ),
      ),
    );
    await tester.runAsync(() async {
      for (final asset in AvatarService.builtInAvatars) {
        await precacheImage(
          AssetImage(asset),
          tester.element(find.byType(ShelltyScreen)),
        );
      }
    });
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    await expectLater(
      find.byType(ShelltyScreen),
      matchesGoldenFile('goldens/shellty_tab.png'),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
