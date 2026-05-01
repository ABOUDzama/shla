import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _soundEnabled = SettingsService.isSoundEnabled;
  bool _vibrationEnabled = SettingsService.isVibrationEnabled;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // State removed as it was unreferenced in build

  // InitState and loadSyncInfo removed as they only updated unused fields

  // Manual sync methods removed as they were unreferenced

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        backgroundColor: Colors.deepOrange,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingTile(
            title: 'المؤثرات الصوتية',
            subtitle: 'تشغيل أو إيقاف أصوات الألعاب',
            icon: Icons.volume_up,
            value: _soundEnabled,
            onChanged: (value) async {
              await SettingsService.setSoundEnabled(value);
              setState(() => _soundEnabled = value);
            },
          ),
          const Divider(),
          _buildSettingTile(
            title: 'الاهتزاز',
            subtitle: 'تشغيل أو إيقاف الاهتزاز عند اللمس أو الخسارة',
            icon: Icons.vibration,
            value: _vibrationEnabled,
            onChanged: (value) async {
              await SettingsService.setVibrationEnabled(value);
              setState(() => _vibrationEnabled = value);
            },
          ),
          const Divider(),
          const Divider(),
          ListTile(
            title: const Text(
              'عن التطبيق',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('ألعاب الأصدقاء - النسخة الماركة'),
            leading: const Icon(Icons.info_outline, color: Colors.deepOrange),
            trailing: const Text('v0.2.1'),
          ),
        ],
      ),
    );
  }


  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      secondary: Icon(icon, color: Colors.deepOrange),
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.deepOrange,
    );
  }
}
