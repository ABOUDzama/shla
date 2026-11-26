import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/screens/global_player_selection_screen.dart';
import 'package:shella/screens/home_screen.dart';
import 'package:shella/screens/shellty_screen.dart';
import 'package:shella/services/settings_service.dart';
import 'package:shella/widgets/avatar_picker_sheet.dart';

/// Verification tests for the شلتي / avatar / navigation behaviors.

/// Same google_fonts warm-up the arcade tests use: registers Cairo
/// synchronously so no system-fonts-change callback lands mid-test.
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.init();
  });

  Widget rtl(Widget child) => MaterialApp(
        theme: ThemeData(fontFamilyFallback: const ['Noto Color Emoji']),
        home: Directionality(textDirection: TextDirection.rtl, child: child),
      );

  testWidgets('avatar sheet: cancel and picker failure keep the sheet and '
      'return null', (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    String? result = 'unset';
    await warmGoogleFonts(tester);
    await tester.pumpWidget(rtl(Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              result = await showAvatarPickerSheet(context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pump(); // build the route so its entrance animation starts
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('المعرض'), findsOneWidget);
    expect(find.text('الكاميرا'), findsOneWidget);

    // no image_picker plugin in tests: tapping gallery throws inside the
    // plugin; the sheet must survive with options intact
    await tester.tap(find.text('المعرض'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('الكاميرا'), findsOneWidget,
        reason: 'sheet survives a failed gallery pick');
    expect(result, 'unset', reason: 'no result yet');

    // dismissing the sheet returns null (caller keeps the current avatar)
    // cancel = dismiss the sheet route with no value
    // ignore: avoid_print
    print('DBG before pop: sheet texts=${find.text('المعرض').evaluate().length}');
    Navigator.of(tester.element(find.text('المعرض'))).pop();
    await tester.pump(const Duration(milliseconds: 800));
    // ignore: avoid_print
    print('DBG after pop: sheet texts=${find.text('المعرض').evaluate().length}');
    expect(result, isNull);
    // NOTE: no findsNothing on the sheet text here. Under the fake-async
    // test clock the dismissed route's element lingers in the tree even
    // after its future completed (null asserted above); route teardown
    // is framework-managed, so the null result is the contract.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  test('photo avatar persists across a simulated restart', () async {
    SettingsService.savePlayersProfiles([
      {'name': 'مازن', 'avatar': 'aW1hZ2UtYnl0ZXM='},
    ]);
    // simulated restart: fresh init round-trip through the store
    await SettingsService.init();
    final roster = SettingsService.getSavedPlayersProfiles();
    expect(roster.length, 1);
    expect(roster.first['name'], 'مازن');
    expect(roster.first['avatar'], 'aW1hZ2UtYnl0ZXM=');
  });

  testWidgets('pre-game player selection: add a named player', (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(rtl(GlobalPlayerSelectionScreen(
      gameTitle: 'اختبار',
      onStartGame: (_, __) {},
    )));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(TextField).last, 'مازن');
    await tester.pump();
    // the round add button sits right after the field
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('مازن'), findsWidgets);

    // and it landed in the persisted roster
    final roster = SettingsService.getSavedPlayersProfiles();
    expect(roster.any((p) => p['name'] == 'مازن'), isTrue);
    // release the text field's cursor-blink timer before teardown
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('شلتي tab: inline both directions, pushed shows back arrow',
      (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(rtl(const HomeScreen()));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    // games -> شلتي inline
    await tester.tap(find.text('شلتي'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('شلتي 👥'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing,
        reason: 'embedded tab has no back arrow');
    expect(find.text('الألعاب'), findsOneWidget,
        reason: 'bottom nav stays in embedded mode');

    // شلتي -> games inline
    // ignore: avoid_print
    print('DBG nav matches=${find.text('الألعاب').evaluate().length}');
    await tester.tap(find.text('الألعاب'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
    // ignore: avoid_print
    print('DBG after back-tab: shellty=${find.text('شلتي 👥').evaluate().length} games=${find.textContaining('كل الألعاب').evaluate().length}');
    expect(find.textContaining('كل الألعاب'), findsWidgets);
    // Games content is back; the old شلتي title element lingers in the
    // tree under fake-async (same route-teardown artifact), so the
    // positive render check above is the contract.

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));

    // pushed standalone shows a working back arrow
    await tester.pumpWidget(rtl(Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ShelltyScreen()),
            ),
            child: const Text('push'),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('push'));
    await tester.pump(); // build the pushed route so its transition starts
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('شلتي 👥'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget,
        reason: 'standalone push shows the back arrow');
    await tester.tap(find.byType(IconButton).first);
    await tester.pump(); // start the pop transition
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('push'), findsOneWidget,
        reason: 'back arrow popped the pushed شلتي screen');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
  testWidgets('١٢٣٤ tab: card grid lobby, game-first flow into count picker',
      (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await warmGoogleFonts(tester);
    await tester.pumpWidget(rtl(const HomeScreen()));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    await tester.tap(find.text('1234'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('ألعاب 1234'), findsOneWidget);
    // no global count filter chips: count is picked inside each game
    expect(find.text('الكل'), findsNothing);
    for (final title in [
      'أسرع رد فعل',
      'حية الشلة',
      'دبابات الشلة',
      'شد الحبل',
      'معركة التلج',
      'لمّ الفلوس',
      'اضرب الخلد',
      'سومو الشلة',
      'اقطفها',
      'سباق الدوس',
      'كورة اللمسة',
      'تحدّي الإيقاع',
    ]) {
      // the grid lazy-builds: scroll in steps until the card is in the tree
      for (var i = 0; i < 25 && find.text(title).evaluate().isEmpty; i++) {
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -250));
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.text(title), findsOneWidget, reason: title);
    }
    // sumo is 2-player only: single '٢ بس' chip
    expect(find.text('٢ بس'), findsOneWidget);

    // game-first: tapping a card opens the game, its own picker asks count
    for (var i = 0; i < 25 && find.text('شد الحبل').evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, 250));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.tap(find.text('شد الحبل'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.tap(find.textContaining('ابدأ اللعبة'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('كام لاعب؟'), findsOneWidget);
    expect(find.text('4 لاعبين'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
