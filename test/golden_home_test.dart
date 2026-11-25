import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/screens/home_screen.dart';
import 'package:shella/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await SettingsService.init();
    // Preload Cairo under its plain family name (setUpAll is real-async, so
    // file IO works) - engine falls back to it while google_fonts' async
    // registration is pending under the fake-async test clock.
    for (final name in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black']) {
      final bytes = await File('assets/fonts/Cairo-' + name + '.ttf').readAsBytes();
      final loader = FontLoader('Cairo')
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
    final icons = await File(
      Platform.environment['HOME']! + '/sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
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

  testWidgets('home screen renders improved game grid', (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamilyFallback: const ['Noto Color Emoji']),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: HomeScreen(),
        ),
      ),
    );
    // Fixed pumps: the header shimmer loops forever, so no pumpAndSettle.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    // Decode asset images (real async) so the header logo appears in goldens.
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/icon.png'),
        tester.element(find.byType(HomeScreen)),
      );
    });
    await tester.pump();
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/home_screen.png'),
    );

    // Scroll to the end: the two new games carry the جديد badge.
    final scrollable = find.byType(Scrollable).first;
    for (var i = 0; i < 12; i++) {
      await tester.drag(scrollable, const Offset(0, -350));
      await tester.pump(const Duration(milliseconds: 300));
    }
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/home_screen_new_games.png'),
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
