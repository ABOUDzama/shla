import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/widgets/avatar_picker_sheet.dart';
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

  testWidgets('golden: avatar picker sheet', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(builder: (c) => Scaffold(
          backgroundColor: const Color(0xFFFFF6EA),
          body: Center(child: ElevatedButton(
              onPressed: () => showAvatarPickerSheet(c),
              child: const Text('x'))))),
      ),
    ));
    await tester.tap(find.text('x'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() async {
      for (final asset in AvatarService.builtInAvatars) {
        await precacheImage(AssetImage(asset),
            tester.element(find.byType(Scaffold)));
      }
    });
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/avatar_picker_chars.png'));
  });
}
