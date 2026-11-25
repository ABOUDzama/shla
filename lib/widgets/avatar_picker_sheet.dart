import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/avatar_service.dart';
import '../theme/flat_theme.dart';

/// Bottom sheet offering the built-in Shla character avatars plus the
/// device gallery/camera. Returns the stored avatar value (`asset:<path>`
/// or a base64 photo), or null when cancelled.
Future<String?> showAvatarPickerSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: FlatColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => const _AvatarPickerSheet(),
  );
}

class _AvatarPickerSheet extends StatelessWidget {
  const _AvatarPickerSheet();

  Future<void> _pickPhoto(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 200,
      maxHeight: 200,
      imageQuality: 70,
    );
    if (picked != null && context.mounted) {
      final bytes = await picked.readAsBytes();
      Navigator.pop(context, base64Encode(bytes));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FlatColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('اختار صورة', style: FlatDecor.title(size: 18),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < AvatarService.builtInAvatars.length; i++)
                  GestureDetector(
                    key: Key('builtin_avatar_$i'),
                    onTap: () => Navigator.pop(
                        context,
                        '${AvatarService.assetPrefix}${AvatarService.builtInAvatars[i]}'),
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: FlatColors.border, width: 3),
                        image: DecorationImage(
                            image: AssetImage(AvatarService.builtInAvatars[i]),
                            fit: BoxFit.cover),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto(context, ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined,
                        color: FlatColors.ink),
                    label: Text('المعرض',
                        style: GoogleFonts.cairo(
                            color: FlatColors.ink,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto(context, ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined,
                        color: FlatColors.ink),
                    label: Text('الكاميرا',
                        style: GoogleFonts.cairo(
                            color: FlatColors.ink,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
