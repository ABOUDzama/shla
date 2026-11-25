import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/avatar_service.dart';
import '../widgets/avatar_picker_sheet.dart';
import '../services/settings_service.dart';
import '../services/score_service.dart';
import '../theme/funky_theme.dart';

class GlobalPlayerSelectionScreen extends StatefulWidget {
  final int minPlayers;
  final int? maxPlayers;
  final String gameTitle;
  final Function(BuildContext context, List<String> selectedPlayers)
  onStartGame;

  const GlobalPlayerSelectionScreen({
    super.key,
    required this.gameTitle,
    required this.onStartGame,
    this.minPlayers = 2,
    this.maxPlayers,
  });

  @override
  State<GlobalPlayerSelectionScreen> createState() =>
      _GlobalPlayerSelectionScreenState();
}

class _GlobalPlayerSelectionScreenState
    extends State<GlobalPlayerSelectionScreen> {
  final TextEditingController _playerCtrl = TextEditingController();
  List<Map<String, String>> _allSavedPlayers = [];
  final Set<String> _selectedPlayerNames = {};
  String? _tempAvatarBase64;
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  void _loadPlayers() {
    setState(() {
      _refreshRoster();
    });
  }

  /// Re-reads the roster from SettingsService. Called on every build so
  /// friends added/edited/deleted in شلتي while this screen sits in the
  /// navigation stack appear the moment the user returns to it.
  void _refreshRoster() {
    _allSavedPlayers = SettingsService.getSavedPlayersProfiles();
  }

  Future<void> _pickTempAvatar() async {
    if (_isPickingImage) return;
    final value = await showAvatarPickerSheet(context);
    if (value != null && mounted) {
      setState(() => _tempAvatarBase64 = value);
    }
  }

  void _addPlayer() {
    final name = _playerCtrl.text.trim();
    if (name.isNotEmpty) {
      bool exists = _allSavedPlayers.any((p) => p['name'] == name);
      if (!exists) {
        setState(() {
          final newPlayer = {'name': name, 'avatar': _tempAvatarBase64 ?? ''};
          _allSavedPlayers.insert(0, newPlayer);
          _selectedPlayerNames.add(name);
          _tempAvatarBase64 = null;
        });
        SettingsService.savePlayersProfiles(_allSavedPlayers);
        _playerCtrl.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('هذا الاسم موجود بالفعل')),
        );
      }
    }
  }

  void _removePlayer(Map<String, String> player) {
    setState(() {
      _allSavedPlayers.removeWhere((p) => p['name'] == player['name']);
      _selectedPlayerNames.remove(player['name']);
    });
    SettingsService.savePlayersProfiles(_allSavedPlayers);
  }

  void _toggleSelection(String name) {
    setState(() {
      if (_selectedPlayerNames.contains(name)) {
        _selectedPlayerNames.remove(name);
      } else {
        if (widget.maxPlayers == null ||
            _selectedPlayerNames.length < widget.maxPlayers!) {
          _selectedPlayerNames.add(name);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'الحد الأقصى ${widget.maxPlayers} لاعبين',
                style: GoogleFonts.cairo(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  void _startGame() {
    if (_selectedPlayerNames.length >= widget.minPlayers) {
      final scoreService = ScoreService();
      final selectedList = _selectedPlayerNames.toList();

      if (scoreService.players.isEmpty) {
        scoreService.setPlayers(selectedList);
      }

      widget.onStartGame(context, selectedList);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تحتاج على الأقل ${widget.minPlayers} لاعبين للبدء',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _refreshRoster(); // always in sync with شلتي edits made while pushed
    final canStart = _selectedPlayerNames.length >= widget.minPlayers;

    return Scaffold(
      body: FunkyBackground(
        accent: FunkyColors.cyan,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 14),
                // Header: round back chip + neon game title
                Row(
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
                            color: FunkyColors.cyan.withValues(alpha: 0.5),
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
                        widget.gameTitle,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: FunkyColors.cyan.withValues(alpha: 0.7),
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
                const SizedBox(height: 26),

                SizedBox(
                  height: 72,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final f in [
                        'assets/avatars_2d/friend2.png',
                        'assets/avatars_2d/friend1.png',
                        'assets/avatars_2d/friend3.png',
                      ])
                        Align(
                          widthFactor: 0.62,
                          child: Image.asset(f, height: 70),
                        ),
                    ],
                  ),
                ),
                Center(
                  child: Text(
                    'مين هيلعب؟ 🎮',
                    style: GoogleFonts.cairo(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: FunkyDecor.pill(FunkyColors.violet),
                    child: Text(
                      'العدد المسموح: ${widget.minPlayers} - ${widget.maxPlayers ?? "مفتوح"}',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Add-player card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration:
                      FunkyDecor.glowCard(FunkyColors.cyan, radius: 22),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _pickTempAvatar,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: FunkyColors.bgDeep.withValues(alpha: 0.6),
                            border: Border.all(
                              color: FunkyColors.cyan.withValues(alpha: 0.6),
                              width: 1.4,
                            ),
                          ),
                          child: AvatarService.providerFor(
                                      _tempAvatarBase64) !=
                                  null
                              ? ClipOval(
                                  child: Image(
                                      image: AvatarService.providerFor(
                                          _tempAvatarBase64)!,
                                      fit: BoxFit.cover))
                              : const Icon(Icons.camera_alt_outlined,
                                  color: Colors.white70, size: 22),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: _playerCtrl,
                          style: GoogleFonts.cairo(
                              color: Colors.white, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'اسم لاعب جديد',
                            hintStyle:
                                GoogleFonts.cairo(color: Colors.white38),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onSubmitted: (_) => _addPlayer(),
                        ),
                      ),
                      GestureDetector(
                        onTap: _addPlayer,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient:
                                FunkyDecor.accentGradient(FunkyColors.magenta),
                            boxShadow: [
                              BoxShadow(
                                color: FunkyColors.magenta
                                    .withValues(alpha: 0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.add_rounded,
                              color: Colors.white, size: 26),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Player list: ticket cards, selected = accent gradient edge
                Expanded(
                  child: _allSavedPlayers.isEmpty
                      ? Center(
                          child: Text(
                            'لا يوجد لاعبين مسجلين حالياً\nقم بإضافة أصدقائك للبدء',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                                fontSize: 15, color: Colors.white38),
                          ).animate().fadeIn(),
                        )
                      : ListView.builder(
                          itemCount: _allSavedPlayers.length,
                          physics: const BouncingScrollPhysics(),
                          itemBuilder: (context, index) {
                            final player = _allSavedPlayers[index];
                            final name = player['name'] ?? '';
                            final avatar = player['avatar'];
                            final isSelected =
                                _selectedPlayerNames.contains(name);
                            final accent = FunkyColors
                                .accents[index % FunkyColors.accents.length];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: FunkyColors.card,
                                borderRadius: BorderRadius.circular(18),
                                gradient: isSelected
                                    ? LinearGradient(
                                        begin: Alignment.centerRight,
                                        end: Alignment.centerLeft,
                                        colors: [
                                          accent.withValues(alpha: 0.35),
                                          FunkyColors.card,
                                        ],
                                      )
                                    : null,
                                border: Border.all(
                                  color: isSelected
                                      ? accent
                                      : Colors.white.withAlpha(14),
                                  width: isSelected ? 1.8 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color:
                                              accent.withValues(alpha: 0.35),
                                          blurRadius: 12,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Material(
                                type: MaterialType.transparency,
                                child: ListTile(
                                  onTap: () => _toggleSelection(name),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 4),
                                  leading: Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: FunkyColors.cardLight,
                                      border: Border.all(
                                        color: accent.withValues(
                                            alpha: isSelected ? 0.95 : 0.4),
                                        width: 1.6,
                                      ),
                                    ),
                                    child: AvatarService.providerFor(
                                                avatar) !=
                                            null
                                        ? ClipOval(
                                            child: Image(
                                                image:
                                                    AvatarService.providerFor(
                                                        avatar)!,
                                                fit: BoxFit.cover))
                                        : Center(
                                            child: Text(
                                              name.isNotEmpty
                                                  ? name[0]
                                                  : '?',
                                              style: GoogleFonts.cairo(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 17,
                                              ),
                                            ),
                                          ),
                                  ),
                                  title: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.cairo(
                                      fontSize: 17,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white70,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? Icon(Icons.check_circle,
                                          color: accent, size: 24)
                                      : IconButton(
                                          icon: const Icon(Icons.close,
                                              color: Colors.white24,
                                              size: 18),
                                          onPressed: () =>
                                              _removePlayer(player),
                                        ),
                                ),
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 300.ms)
                                .slideX(begin: 0.05, curve: Curves.easeOut);
                          },
                        ),
                ),

                // Start button
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: Opacity(
                      opacity: canStart ? 1 : 0.4,
                      child: FunkyButton(
                        label: 'بدء اللعبة',
                        onPressed: canStart ? _startGame : () {},
                        accent: FunkyColors.magenta,
                        icon: Icons.play_arrow_rounded,
                        fontSize: 19,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
