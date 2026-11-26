import 'package:flutter/material.dart';
import '../services/avatar_service.dart';
import '../services/settings_service.dart';
import '../theme/flat_theme.dart';

/// First-launch flow: a welcome message from the Shla, then name + avatar
/// (one of the 8 card characters). Saved as the current user's profile.
/// Also used (edit: true) to change the profile later.
class WelcomeScreen extends StatefulWidget {
  final bool edit;
  final VoidCallback? onDone;
  const WelcomeScreen({super.key, this.edit = false, this.onDone});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late bool _intro = !widget.edit;
  final _name = TextEditingController(text: SettingsService.userName);
  String? _avatar = AvatarService.isBuiltIn(SettingsService.userAvatar ?? '')
      ? SettingsService.userAvatar
      : '${AvatarService.assetPrefix}assets/avatars/avatar_boy_green.png';

  bool get _ready => _name.text.trim().isNotEmpty && _avatar != null;

  Future<void> _save() async {
    if (!_ready) return;
    await SettingsService.setUserName(_name.text.trim());
    await SettingsService.setUserAvatar(_avatar);
    if (!mounted) return;
    if (widget.onDone != null) {
      widget.onDone!();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Widget _introView() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.asset('assets/avatars_2d/group.jpg',
                        fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: FlatDecor.card(radius: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('رسالة من الشلة', style: FlatDecor.body(size: 12.5)),
                      const SizedBox(height: 4),
                      Text('أهلاً بيك في الشلة! 🎉',
                          style: FlatDecor.title(size: 22)),
                      const SizedBox(height: 6),
                      Text(
                        'كنا مستنيينك. ألعاب وضحك ومنافسة مع صحابك. عرّفنا بنفسك الأول وبعدها نبدأ.',
                        style: FlatDecor.body(size: 15),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: _cta('يلا نبدأ', () => setState(() => _intro = false), true),
        ),
      ],
    );
  }

  Widget _cta(String label, VoidCallback onTap, bool enabled) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: FlatDecor.button(FlatColors.day, radius: 20),
          alignment: Alignment.center,
          child: Text(label, style: FlatDecor.title(size: 18, color: Colors.white)),
        ),
      ),
    );
  }

  Widget _profileView() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: FlatColors.ink, width: 3),
                      image: _avatar == null
                          ? null
                          : DecorationImage(
                              image: AvatarService.providerFor(_avatar)!,
                              fit: BoxFit.cover),
                    ),
                    child: _avatar == null
                        ? const Icon(Icons.person, size: 44, color: FlatColors.ink)
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                    child: Text('اسمك إيه؟', style: FlatDecor.title(size: 22))),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: FlatDecor.card(radius: 18),
                  child: TextField(
                    key: const ValueKey('profile_name'),
                    controller: _name,
                    maxLength: 16,
                    onChanged: (_) => setState(() {}),
                    textAlign: TextAlign.center,
                    style: FlatDecor.title(size: 18),
                    decoration: InputDecoration(
                      hintText: 'اكتب اسمك',
                      hintStyle: FlatDecor.body(size: 16),
                      border: InputBorder.none,
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                    child: Text('اختار شخصيتك',
                        style: FlatDecor.title(size: 18))),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final a in AvatarService.pickerAvatars)
                      GestureDetector(
                        key: ValueKey('pick_$a'),
                        onTap: () => setState(
                            () => _avatar = '${AvatarService.assetPrefix}$a'),
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: _avatar ==
                                        '${AvatarService.assetPrefix}$a'
                                    ? FlatColors.ink
                                    : FlatColors.border,
                                width: _avatar ==
                                        '${AvatarService.assetPrefix}$a'
                                    ? 4
                                    : 2),
                            image: DecorationImage(
                                image: AssetImage(a), fit: BoxFit.cover),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: _cta(widget.edit ? 'حفظ' : 'دخول الشلة', _save, _ready),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlatColors.bg,
      resizeToAvoidBottomInset: true,
      appBar: widget.edit
          ? AppBar(
              backgroundColor: FlatColors.bg,
              iconTheme: const IconThemeData(color: FlatColors.ink),
              title: Text('بروفايلي', style: FlatDecor.title(size: 20)))
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _intro ? _introView() : _profileView(),
        ),
      ),
    );
  }
}
