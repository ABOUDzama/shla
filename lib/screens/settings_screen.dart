import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/settings_service.dart';
import '../theme/funky_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _soundEnabled = SettingsService.isSoundEnabled;
  bool _vibrationEnabled = SettingsService.isVibrationEnabled;

  TextStyle get _titleStyle => GoogleFonts.cairo(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      );

  TextStyle get _subtitleStyle => GoogleFonts.cairo(
        fontSize: 12.5,
        color: Colors.white60,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FunkyBackground(
        accent: FunkyColors.amber,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: FunkyColors.card,
                          border: Border.all(
                            color: FunkyColors.amber.withValues(alpha: 0.5),
                            width: 1.3,
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'الإعدادات',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: FunkyColors.amber.withValues(alpha: 0.7),
                              blurRadius: 14,
                            ),
                          ],
                        ).copyWith(
                            fontFamilyFallback: const ['Noto Color Emoji']),
                      ),
                    ),
                    const SizedBox(width: 42),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildSettingTile(
                      title: 'المؤثرات الصوتية',
                      subtitle: 'تشغيل أو إيقاف أصوات الألعاب',
                      icon: Icons.volume_up_rounded,
                      accent: FunkyColors.cyan,
                      value: _soundEnabled,
                      onChanged: (value) async {
                        await SettingsService.setSoundEnabled(value);
                        setState(() => _soundEnabled = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildSettingTile(
                      title: 'الاهتزاز',
                      subtitle: 'تشغيل أو إيقاف الاهتزاز عند اللمس أو الخسارة',
                      icon: Icons.vibration_rounded,
                      accent: FunkyColors.magenta,
                      value: _vibrationEnabled,
                      onChanged: (value) async {
                        await SettingsService.setVibrationEnabled(value);
                        setState(() => _vibrationEnabled = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration:
                          FunkyDecor.glowCard(FunkyColors.violet, radius: 20),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: FunkyColors.bgDeep.withValues(alpha: 0.6),
                              border: Border.all(
                                color:
                                    FunkyColors.violet.withValues(alpha: 0.6),
                                width: 1.4,
                              ),
                            ),
                            child: const Icon(Icons.info_outline_rounded,
                                color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('عن التطبيق', style: _titleStyle),
                                Text('ألعاب الأصدقاء - شِلَّة',
                                    style: _subtitleStyle),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration:
                                FunkyDecor.pill(FunkyColors.violet),
                            child: Text(
                              'v1.2.1',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: FunkyDecor.glowCard(accent, radius: 20),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: FunkyColors.bgDeep.withValues(alpha: 0.6),
              border: Border.all(
                color: accent.withValues(alpha: 0.6),
                width: 1.4,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _titleStyle),
                Text(subtitle, style: _subtitleStyle),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: accent.withValues(alpha: 0.8),
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white.withAlpha(20),
          ),
        ],
      ),
    );
  }
}
