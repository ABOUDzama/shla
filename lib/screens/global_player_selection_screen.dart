import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../services/settings_service.dart';
import '../services/score_service.dart';

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
      _allSavedPlayers = SettingsService.getSavedPlayersProfiles();
    });
  }

  Future<void> _pickTempAvatar() async {
    if (_isPickingImage) return;
    
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: Colors.white70),
            title: Text('المعرض', style: GoogleFonts.cairo(color: Colors.white)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined, color: Colors.white70),
            title: Text('الكاميرا', style: GoogleFonts.cairo(color: Colors.white)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );

    if (source == null) return;
    
    _isPickingImage = true;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 200,
        maxHeight: 200,
        imageQuality: 70,
      );
      if (picked != null && mounted) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _tempAvatarBase64 = base64Encode(bytes);
        });
      }
    } finally {
      _isPickingImage = false;
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
    final canStart = _selectedPlayerNames.length >= widget.minPlayers;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // Clean Header
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.gameTitle,
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              Text(
                'اختيار اللاعبين',
                style: GoogleFonts.cairo(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'العدد المسموح: ${widget.minPlayers} - ${widget.maxPlayers ?? "مفتوح"}',
                style: GoogleFonts.cairo(fontSize: 14, color: Colors.white38),
              ),
              const SizedBox(height: 32),

              // Minimalist Add Player Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withAlpha(15)),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _pickTempAvatar,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withAlpha(10),
                        ),
                        child: _tempAvatarBase64 != null
                            ? ClipOval(child: Image.memory(base64Decode(_tempAvatarBase64!), fit: BoxFit.cover))
                            : const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 22),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _playerCtrl,
                        style: GoogleFonts.cairo(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'اسم لاعب جديد',
                          hintStyle: GoogleFonts.cairo(color: Colors.white24),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: (_) => _addPlayer(),
                      ),
                    ),
                    IconButton(
                      onPressed: _addPlayer,
                      icon: const Icon(Icons.add_circle, color: Color(0xFF6366F1), size: 36),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Refined Player List
              Expanded(
                child: _allSavedPlayers.isEmpty
                    ? Center(
                        child: Text(
                          'لا يوجد لاعبين مسجلين حالياً\nقم بإضافة أصدقائك للبدء',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(fontSize: 15, color: Colors.white24),
                        ).animate().fadeIn(),
                      )
                    : ListView.builder(
                        itemCount: _allSavedPlayers.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final player = _allSavedPlayers[index];
                          final name = player['name'] ?? '';
                          final avatar = player['avatar'];
                          final isSelected = _selectedPlayerNames.contains(name);

                          return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.indigo.withAlpha(25) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF6366F1).withAlpha(120) : Colors.white.withAlpha(10),
                                  ),
                                ),
                                child: ListTile(
                                  onTap: () => _toggleSelection(name),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  leading: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white10,
                                    ),
                                    child: avatar != null && avatar.isNotEmpty
                                        ? ClipOval(child: Image.memory(base64Decode(avatar), fit: BoxFit.cover))
                                        : Center(
                                            child: Text(
                                              name.isNotEmpty ? name[0] : '?',
                                              style: GoogleFonts.cairo(color: Colors.white70, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                  ),
                                  title: Text(
                                    name,
                                    style: GoogleFonts.cairo(
                                      fontSize: 17,
                                      color: isSelected ? Colors.white : Colors.white70,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  trailing: isSelected 
                                    ? const Icon(Icons.check_circle, color: Color(0xFF6366F1), size: 22)
                                    : IconButton(
                                        icon: const Icon(Icons.close, color: Colors.white24, size: 18),
                                        onPressed: () => _removePlayer(player),
                                      ),
                                ),
                              )
                              .animate()
                              .fadeIn(duration: 300.ms)
                              .slideX(begin: 0.05, curve: Curves.easeOut);
                        },
                      ),
              ),

              // Simple Start Button
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: canStart ? _startGame : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white.withAlpha(5),
                      disabledForegroundColor: Colors.white24,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      'بدء اللعبة',
                      style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
