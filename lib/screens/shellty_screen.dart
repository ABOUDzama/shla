import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/avatar_service.dart';
import '../services/settings_service.dart';
import '../theme/flat_theme.dart';
import '../widgets/avatar_picker_sheet.dart';

/// شلتي — the user's saved crew: add friends with a name and a picture
/// (built-in Shla characters or a device photo), edit or remove them. The
/// roster persists in SettingsService and feeds the pre-game player
/// selection, so edits here show up everywhere players are picked.
class ShelltyScreen extends StatefulWidget {
  /// When embedded inside the home tab bar, no back button is shown.
  final bool embedded;

  const ShelltyScreen({super.key, this.embedded = false});

  @override
  State<ShelltyScreen> createState() => _ShelltyScreenState();
}

class _ShelltyScreenState extends State<ShelltyScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  List<Map<String, String>> _players = [];
  String? _newAvatar;

  @override
  void initState() {
    super.initState();
    _players = SettingsService.getSavedPlayersProfiles();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _persist() async {
    await SettingsService.savePlayersProfiles(_players);
  }

  Future<void> _pickNewAvatar() async {
    final value = await showAvatarPickerSheet(context);
    if (value != null && mounted) setState(() => _newAvatar = value);
  }

  void _addFriend() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    if (_players.any((p) => p['name'] == name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('الاسم ده موجود في شلتك',
                style: GoogleFonts.cairo())),
      );
      return;
    }
    setState(() {
      _players.insert(0, {'name': name, 'avatar': _newAvatar ?? ''});
      _newAvatar = null;
      _nameCtrl.clear();
    });
    _persist();
  }

  void _removeFriend(Map<String, String> player) {
    setState(() => _players.removeWhere((p) => p['name'] == player['name']));
    _persist();
  }

  Future<void> _editFriend(Map<String, String> player) async {
    final nameCtrl = TextEditingController(text: player['name']);
    String? avatar = player['avatar']!.isEmpty ? null : player['avatar'];
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlatColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final value = await showAvatarPickerSheet(context);
                      if (value != null) {
                        setSheetState(() => avatar = value);
                      }
                    },
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: FlatColors.tileWhite,
                      backgroundImage: AvatarService.providerFor(avatar),
                      child: AvatarService.providerFor(avatar) == null
                          ? const Icon(Icons.add_a_photo_outlined,
                              color: FlatColors.ink)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('دوس على الصورة عشان تغيّرها',
                      style: FlatDecor.body(size: 12)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    textAlign: TextAlign.center,
                    style: FlatDecor.title(size: 16),
                    decoration: InputDecoration(
                      hintText: 'الاسم',
                      filled: true,
                      fillColor: FlatColors.tileWhite,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: FlatColors.mafia),
                          onPressed: () {
                            _removeFriend(player);
                            Navigator.pop(sheetContext, false);
                          },
                          child: Text('احذف',
                              style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: FlatColors.ink),
                          onPressed: () =>
                              Navigator.pop(sheetContext, true),
                          child: Text('احفظ',
                              style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (saved == true && mounted) {
      final newName = nameCtrl.text.trim();
      setState(() {
        final idx = _players.indexWhere((p) => p['name'] == player['name']);
        if (idx >= 0 && newName.isNotEmpty) {
          _players[idx] = {'name': newName, 'avatar': avatar ?? ''};
        }
      });
      _persist();
    }
    // Do not dispose nameCtrl here: the sheet is still animating out and its
    // field detaches asynchronously; disposing early crashes the framework.
  }

  Widget _friendTile(Map<String, String> player, int index) {
    final provider = AvatarService.providerFor(player['avatar']);
    return GestureDetector(
      onTap: () => _editFriend(player),
      child: Container(
        decoration: FlatDecor.card(radius: 20),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor:
                  FlatColors.tilePastels[index % FlatColors.tilePastels.length],
              backgroundImage: provider,
              child: provider == null
                  ? Text(
                      player['name']!.isEmpty ? '؟' : player['name']![0],
                      style: FlatDecor.title(size: 24, color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              player['name']!,
              style: FlatDecor.title(size: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
      children: [
        if (!widget.embedded)
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_forward_rounded,
                  color: FlatColors.ink),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        Text('شلتي 👥', style: FlatDecor.title(size: 24),
            textAlign: TextAlign.center),
        Text('ضيف صحابك بأسمائهم وصورهم، وهتلاقيهم في اختيار اللاعبين',
            style: FlatDecor.body(size: 12.5), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Container(
          decoration: FlatDecor.card(radius: 20),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              GestureDetector(
                onTap: _pickNewAvatar,
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: FlatColors.bg,
                  backgroundImage: AvatarService.providerFor(_newAvatar),
                  child: AvatarService.providerFor(_newAvatar) == null
                      ? const Icon(Icons.add_a_photo_outlined,
                          color: FlatColors.ink, size: 22)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  textAlign: TextAlign.right,
                  style: FlatDecor.title(size: 15),
                  decoration: InputDecoration(
                    hintText: 'اسم صاحبك',
                    hintStyle: FlatDecor.body(size: 14),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _addFriend(),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: FlatColors.ink),
                onPressed: _addFriend,
                child: Text('ضيف',
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_players.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text('شلتك فاضية لسه.. ضيف أول واحد! 🎉',
                style: FlatDecor.body(size: 14),
                textAlign: TextAlign.center),
          )
        else
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
            children: [
              for (var i = 0; i < _players.length; i++)
                _friendTile(_players[i], i),
            ],
          ),
      ],
    );
    if (widget.embedded) return SafeArea(child: content);
    return Scaffold(backgroundColor: FlatColors.bg, body: SafeArea(child: content));
  }
}
