import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../theme/flat_theme.dart';

/// Settings screen in the approved flat language (XO trial direction,
/// user-approved 2026-11-25): cream bg, white cards, ink text, pastel
/// icon tiles, no gradients or glows.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _soundEnabled = SettingsService.isSoundEnabled;
  bool _vibrationEnabled = SettingsService.isVibrationEnabled;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlatColors.bg,
      body: SafeArea(
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
                        color: Colors.white,
                        border:
                            Border.all(color: FlatColors.border, width: 2),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: FlatColors.ink,
                        size: 18,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'الإعدادات',
                      textAlign: TextAlign.center,
                      style: FlatDecor.title(size: 22),
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
                    accent: FlatColors.tilePastels[1],
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
                    accent: FlatColors.tilePastels[5],
                    value: _vibrationEnabled,
                    onChanged: (value) async {
                      await SettingsService.setVibrationEnabled(value);
                      setState(() => _vibrationEnabled = value);
                    },
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: FlatDecor.card(radius: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: FlatColors.tilePastels[0],
                          ),
                          child: const Icon(Icons.info_outline_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('عن التطبيق',
                                  style: FlatDecor.title(size: 16)),
                              Text(
                                'ألعاب الأصدقاء - شِلَّة',
                                style: FlatDecor.body(
                                  size: 12.5,
                                  color:
                                      FlatColors.ink.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: FlatDecor.tag(),
                          child: Text(
                            'v1.2.2',
                            style: FlatDecor.body(
                              size: 12,
                              color: FlatColors.ink.withValues(alpha: 0.75),
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
      decoration: FlatDecor.card(radius: 20),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: FlatDecor.title(size: 16)),
                Text(
                  subtitle,
                  style: FlatDecor.body(
                    size: 12.5,
                    color: FlatColors.ink.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: accent,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: FlatColors.border,
          ),
        ],
      ),
    );
  }
}
