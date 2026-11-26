import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/avatar_service.dart';
import '../widgets/avatar_picker_sheet.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/settings_service.dart';
import '../services/haptic_service.dart';
import '../services/socket_service.dart' as ss;
import '../theme/flat_theme.dart';
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  String? _avatarBase64;
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = SettingsService.userName;
    _avatarBase64 = SettingsService.userAvatar;
  }

  Future<void> _pickAvatar() async {
    if (_isPickingImage) return;
    final value = await showAvatarPickerSheet(context);
    if (value != null && mounted) {
      setState(() => _avatarBase64 = value);
      HapticService.lightImpact();
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برجاء إدخال اسمك')),
      );
      return;
    }

    await SettingsService.setUserName(name);
    await SettingsService.setUserAvatar(_avatarBase64);
    
    // Sync with SocketService if active
    final socket = ss.SocketService();
    if (socket.currentRoomCode != null) {
      await socket.setRoomContext(
        socket.currentRoomCode!,
        name,
        avatar: _avatarBase64,
      );
      // Re-join to announce the update to other players
      socket.forceRoomSync();
    }
    
    HapticService.success();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الملف الشخصي بنجاح ✨')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlatColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 14),
              // Header: back chip + title
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: FlatColors.border, width: 2),
                      ),
                      child: const Directionality(
                        textDirection: TextDirection.rtl,
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: FlatColors.ink,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'الملف الشخصي',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: FlatDecor.title(size: 22),
                    ),
                  ),
                  const SizedBox(width: 42),
                ],
              ),
              const SizedBox(height: 32),

              // Avatar with ink ring + camera badge
              Center(
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    alignment: Alignment.bottomLeft,
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border:
                              Border.all(color: FlatColors.ink, width: 3),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: ClipOval(
                          child: AvatarService.providerFor(_avatarBase64) !=
                                  null
                              ? Image(
                                  image: AvatarService.providerFor(
                                      _avatarBase64)!,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: FlatColors.border,
                                  child: const Icon(
                                    Icons.person_rounded,
                                    size: 80,
                                    color: FlatColors.ink,
                                  ),
                                ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: FlatColors.ink,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: FlatColors.bg,
                            width: 3,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'تغيير الصورة',
                textDirection: TextDirection.rtl,
                style: FlatDecor.body(size: 14)
                    .copyWith(fontWeight: FontWeight.w800),
              ),

              const SizedBox(height: 40),

              // Name input card
              Container(
                decoration: FlatDecor.card(radius: 22),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _nameController,
                  style: FlatDecor.body(size: 17),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'أدخل اسمك هنا',
                    hintStyle: FlatDecor.body(size: 15).copyWith(
                        color: FlatColors.ink.withValues(alpha: 0.4)),
                    icon: const Icon(Icons.badge_rounded,
                        color: FlatColors.ink),
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1, end: 0),

              const SizedBox(height: 40),

              // Save button
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: _saveProfile,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: FlatDecor.button(FlatColors.ink, radius: 18),
                    child: Center(
                      child: Text(
                        'حفظ التغييرات ✓',
                        textDirection: TextDirection.rtl,
                        style: FlatDecor.title(
                            size: 19, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.5, end: 0),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
