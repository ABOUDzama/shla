import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/screens/shellty_screen.dart';
import 'package:shella/services/settings_service.dart';
import 'package:shella/services/avatar_service.dart';

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
    final emojiBytes = await File('test/fonts_NotoColorEmoji.ttf').readAsBytes();
    final emojiLoader = FontLoader('Noto Color Emoji')
      ..addFont(Future.value(ByteData.sublistView(emojiBytes)));
    await emojiLoader.load();
  });

  /// Lets async font-load notifications settle so their transient callback
  /// fires inside the test, not after teardown (known flutter_test artifact).
  Future<void> flushFontCallbacks(WidgetTester tester) async {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await tester.pump();
  }

  Future<void> pumpShellty(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ShelltyScreen()));
    await tester.pump();
  }

  testWidgets('add friend with built-in avatar persists to roster',
      (tester) async {
    SharedPreferences.setMockInitialValues({'sound_enabled': false});
    await SettingsService.init();
    await pumpShellty(tester);
    await flushFontCallbacks(tester);

    expect(find.text('شلتي 👥'), findsOneWidget);
    expect(find.textContaining('شلتك فاضية'), findsOneWidget);

    // open the avatar sheet and pick the first built-in character
    await tester.tap(find.byIcon(Icons.add_a_photo_outlined).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('اختار صورة'), findsOneWidget);
    await tester.tap(find.byKey(const Key('builtin_avatar_0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.byType(TextField).first, 'مونا');
    await tester.tap(find.text('ضيف'));
    await tester.pump();

    expect(find.text('مونا'), findsWidgets);
    final saved = SettingsService.getSavedPlayersProfiles();
    expect(saved.length, 1);
    expect(saved.first['name'], 'مونا');
    expect(saved.first['avatar'],
        '${AvatarService.assetPrefix}${AvatarService.builtInAvatars[0]}');
    await flushFontCallbacks(tester);
  });

  testWidgets('edit name and delete reflect in saved roster', (tester) async {
    SharedPreferences.setMockInitialValues({'sound_enabled': false});
    await SettingsService.init();
    await SettingsService.savePlayersProfiles([
      {
        'name': 'أحمد',
        'avatar':
            '${AvatarService.assetPrefix}${AvatarService.builtInAvatars[1]}'
      },
    ]);
    await pumpShellty(tester);
    await flushFontCallbacks(tester);

    expect(find.text('أحمد'), findsOneWidget);

    // open edit sheet and rename (sheet field is the LAST TextField in tree)
    await tester.tap(find.text('أحمد'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('احفظ'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'أحمد جمال');
    await tester.tap(find.text('احفظ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    var saved = SettingsService.getSavedPlayersProfiles();
    expect(saved.length, 1);
    expect(saved.first['name'], 'أحمد جمال');
    expect(find.text('أحمد جمال'), findsOneWidget);

    // delete via edit sheet
    await tester.tap(find.text('أحمد جمال'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('احذف'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    saved = SettingsService.getSavedPlayersProfiles();
    expect(saved, isEmpty);
    expect(find.textContaining('شلتك فاضية'), findsOneWidget);
    await flushFontCallbacks(tester);
  });

  testWidgets('duplicate name is rejected', (tester) async {
    SharedPreferences.setMockInitialValues({'sound_enabled': false});
    await SettingsService.init();
    await SettingsService.savePlayersProfiles([
      {'name': 'سارة', 'avatar': ''},
    ]);
    await pumpShellty(tester);
    await flushFontCallbacks(tester);

    await tester.enterText(find.byType(TextField).first, 'سارة');
    await tester.tap(find.text('ضيف'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(SettingsService.getSavedPlayersProfiles().length, 1);
    await flushFontCallbacks(tester);
  });
}
