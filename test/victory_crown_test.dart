import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/theme/flat_theme.dart';
import 'package:shella/widgets/victory_friends.dart';
import 'package:shella/services/results_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    for (final name in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black']) {
      final bytes = await File('assets/fonts/Cairo-$name.ttf').readAsBytes();
      final loader = FontLoader('Cairo')..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
    final emojiBytes = await File('test/fonts_NotoColorEmoji.ttf').readAsBytes();
    final l = FontLoader('Noto Color Emoji')..addFont(Future.value(ByteData.sublistView(emojiBytes)));
    await l.load();
    final mi = await File('${Platform.environment['HOME']}/sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytes();
    final il = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(mi)));
    await il.load();
  });

  Future<void> show(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(360, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(backgroundColor: const Color(0xFFFFF4E6), body: Center(child: w))),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(Scaffold));
      for (final n in ['blue', 'purple', 'yellow', 'hijab']) {
        await precacheImage(AssetImage('assets/avatars/card_$n.png'), ctx);
      }
      await Future.delayed(const Duration(milliseconds: 600));
    });
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> end(WidgetTester tester) async {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 600)));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('seat 2 wins: only that avatar is crowned', (tester) async {
    await show(tester, const VictoryFriends(winnerName: 'لاعب 2'));
    expect(find.byKey(const ValueKey('crown_1')), findsOneWidget);
    for (final i in [0, 2, 3]) {
      expect(find.byKey(ValueKey('crown_$i')), findsNothing);
    }
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/victory_crown_seat2.png'));
    await end(tester);
  });

  testWidgets('shared win crowns exactly the listed seats', (tester) async {
    await show(tester, const VictoryFriends(winnerName: 'لاعب 1 و لاعب 3', winnerSeats: [0, 2]));
    expect(find.byKey(const ValueKey('crown_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('crown_2')), findsOneWidget);
    expect(find.byKey(const ValueKey('crown_1')), findsNothing);
    expect(find.byKey(const ValueKey('crown_3')), findsNothing);
    await end(tester);
  });

  testWidgets('shared-win label without explicit seats crowns each named seat',
      (tester) async {
    await show(tester, const VictoryFriends(winnerName: 'لاعب 1 و لاعب 3'));
    expect(find.byKey(const ValueKey('crown_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('crown_2')), findsOneWidget);
    expect(find.byKey(const ValueKey('crown_1')), findsNothing);
    expect(find.byKey(const ValueKey('crown_3')), findsNothing);
    await end(tester);
  });

  testWidgets('BotsWinLabel renders the label and records one bots win',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await show(
        tester,
        BotsWinLabel(
            gameTitle: 'سومو الشلة',
            style: flatCairo(fontSize: 22, fontWeight: FontWeight.w900)
                .copyWith(fontFamilyFallback: const ['Noto Color Emoji'])));
    expect(find.text(kBotsWinnerLabel), findsOneWidget);
    final all = await ResultsService.instance.load();
    expect(all.length, 1);
    expect(all.single.winner, kBotsWinnerLabel);
    expect(all.single.game, 'سومو الشلة');
    await expectLater(
        find.byType(Scaffold), matchesGoldenFile('goldens/bots_win_label.png'));
    await end(tester);
  });

  testWidgets('a name that is not a seat label crowns nobody', (tester) async {
    await show(tester, const VictoryFriends(winnerName: 'سارة'));
    expect(find.byKey(const ValueKey('crown_0')), findsNothing);
    expect(find.byKey(const ValueKey('crown_1')), findsNothing);
    await end(tester);
  });
}
