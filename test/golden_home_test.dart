import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/screens/home_screen.dart';
import 'package:shella/screens/arcade_section_screen.dart';
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


/// Builds throwaway texts in every Cairo weight so google_fonts finishes its
/// async family registration BEFORE the game tree exists (same pattern as
/// the other golden/widget tests).
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

  testWidgets('home screen renders improved game grid', (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await warmGoogleFonts(tester);
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

    // Mid-grid: batch-2 illustrated tiles (تحدي التوازن .. عكس العكاس).
    final scMid = find.byType(Scrollable).first;
    for (var i = 0; i < 3; i++) {
      await tester.drag(scMid, const Offset(0, -350));
      await tester.pump(const Duration(milliseconds: 300));
    }
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/home_screen_mid.png'),
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
    // QA: the last game ticket must scroll fully clear of the floating
    // offline/online switch at the bottom.
    final lastGame = find.text('إيموجي إيه؟');
    expect(lastGame, findsOneWidget);
    final lastRect = tester.getRect(lastGame);
    final switchRect = tester.getRect(find.text('شلتي'));
    expect(lastRect.bottom, lessThan(switchRect.top),
        reason: 'last ticket hidden behind bottom nav: '
            'last=$lastRect switch=$switchRect');
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/home_screen_new_games.png'),
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets('goldens: ١٢٣٤ arcade section tab', (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await warmGoogleFonts(tester);
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
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.tap(find.text('1234'));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    final homeCtx = tester.element(find.byType(HomeScreen));
    await tester.runAsync(() async {
      for (final path in ArcadeSectionScreen.covers.values) {
        await precacheImage(AssetImage(path), homeCtx);
      }
    });
    await tester.pump();
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/home_arcade_section.png'),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('goldens: ١٢٣٤ arcade section full lobby', (tester) async {
    tester.view.physicalSize = const Size(412, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await warmGoogleFonts(tester);
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
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.tap(find.text('1234'));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    final homeCtx = tester.element(find.byType(HomeScreen));
    await tester.runAsync(() async {
      for (final path in ArcadeSectionScreen.covers.values) {
        await precacheImage(AssetImage(path), homeCtx);
      }
    });
    await tester.pump();
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/home_arcade_full.png'),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
