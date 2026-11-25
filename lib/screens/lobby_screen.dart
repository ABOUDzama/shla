import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/socket_service.dart' as ss;
import '../services/settings_service.dart';
import 'room_screen.dart';
import 'profile_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/funky_theme.dart';

class LobbyScreen extends StatefulWidget {
  final bool showBackButton;
  const LobbyScreen({super.key, this.showBackButton = true});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _roomCodeController = TextEditingController();
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  String? _lastRoomCode;
  String? _lastPlayerName;
  String? _lastAvatar;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
    _checkActiveSession();
    ss.SocketService().initSocket();

    ss.SocketService().socket.on('room_created', _onRoomCreated);
    ss.SocketService().socket.on('join_success', _onJoinSuccess);
    ss.SocketService().socket.on('error_message', _onErrorMessage);
  }

  void _onRoomCreated(dynamic data) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    final roomCode = data['roomCode'];
    if (roomCode == null) {
      debugPrint('WebRTC: ERROR - Received room_created but roomCode is null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ فشل في إنشاء الغرفة، حاول مرة أخرى')),
      );
      return;
    }
    
    // ENSURE CONTEXT IS SET IMMEDIATELY TO PREVENT DATA RACES
    ss.SocketService().setRoomContext(
      roomCode,
      SettingsService.userName,
      avatar: SettingsService.userAvatar,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomScreen(
          roomCode: roomCode,
          isHost: true,
          playerName: SettingsService.userName,
          avatarBase64: SettingsService.userAvatar,
        ),
      ),
    );
  }

  void _onJoinSuccess(dynamic data) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomScreen(
          roomCode: _roomCodeController.text.trim(),
          isHost: false,
          playerName: SettingsService.userName,
          avatarBase64: SettingsService.userAvatar,
        ),
      ),
    );
  }

  void _onErrorMessage(dynamic data) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(data['message']),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  Future<void> _checkActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final lastTime = prefs.getInt('last_session_time') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // session valid for 30 minutes
    if (now - lastTime < 30 * 60 * 1000) {
      setState(() {
        _lastRoomCode = prefs.getString('last_room_code');
        _lastPlayerName = prefs.getString('last_player_name');
        _lastAvatar = prefs.getString('last_avatar');
      });
    }
  }

  void _rejoinRoom() {
    if (_lastRoomCode == null) return;
    setState(() => _isLoading = true);

    // Set context first
    ss.SocketService().setRoomContext(
      _lastRoomCode!,
      _lastPlayerName ?? SettingsService.userName,
      avatar: _lastAvatar ?? SettingsService.userAvatar,
    );

    ss.SocketService().socket.emit('join_room', {
      'roomCode': _lastRoomCode,
      'playerName': _lastPlayerName ?? SettingsService.userName,
      'avatar': _lastAvatar ?? SettingsService.userAvatar,
    });

    _roomCodeController.text = _lastRoomCode!; // For navigation logic
  }

  @override
  void dispose() {
    ss.SocketService().socket.off('room_created', _onRoomCreated);
    ss.SocketService().socket.off('join_success', _onJoinSuccess);
    ss.SocketService().socket.off('error_message', _onErrorMessage);
    _roomCodeController.dispose();
    _animController.dispose();
    super.dispose();
  }

  bool _validate() {
    if (SettingsService.userName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'برجاء إعداد اسمك في الملف الشخصي أولاً 👤',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.amber.shade900,
          action: SnackBarAction(
            label: 'إعداد الآن',
            textColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _createRoom() async {
    if (!_validate()) return;
    setState(() => _isLoading = true);

    // ENSURE SOCKET IS CONNECTED BEFORE EMITTING
    if (!ss.SocketService().isConnected) {
      ss.SocketService().initSocket();
      int retries = 0;
      while (!ss.SocketService().isConnected && retries < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        retries++;
      }
      if (!ss.SocketService().isConnected) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تعذر الاتصال بالسيرفر، برجاء التأكد من الإنترنت'),
            ),
          );
        }
        return;
      }
    }

    ss.SocketService().socket.emit('create_room', {
      'playerName': SettingsService.userName,
      'avatar': SettingsService.userAvatar,
    });
    // Timeout بعد 15 ثانية
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ تعذر الاتصال، تحقق من الإنترنت وأعد المحاولة'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    });
  }

  Future<void> _joinRoom() async {
    if (!_validate()) return;
    if (_roomCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('الرجاء إدخال كود الغرفة')));
      return;
    }
    setState(() => _isLoading = true);

    // ENSURE SOCKET IS CONNECTED BEFORE EMITTING
    if (!ss.SocketService().isConnected) {
      ss.SocketService().initSocket();
      int retries = 0;
      while (!ss.SocketService().isConnected && retries < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        retries++;
      }
      if (!ss.SocketService().isConnected) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تعذر الاتصال بالسيرفر، برجاء التأكد من الإنترنت'),
            ),
          );
        }
        return;
      }
    }

    final code = _roomCodeController.text.trim();
    final int? codeInt = int.tryParse(code);
    final Map<String, dynamic> joinPayload = {
      'roomCode': code,
      'room_code': code,
      'room': code,
      'roomId': code,
      'room_id': code,
      'roomName': code,
      'room_name': code,
      if (codeInt != null) ...{
        'roomCodeInt': codeInt,
        'roomIdInt': codeInt,
        'room_id_int': codeInt,
        'id': codeInt,
      },
      'playerName': SettingsService.userName,
      'name': SettingsService.userName,
      'nickname': SettingsService.userName,
      'username': SettingsService.userName,
      'avatar': SettingsService.userAvatar,
    };

    ss.SocketService().socket.emit('join_room', joinPayload);
    ss.SocketService().socket.emit('join', joinPayload);
    ss.SocketService().socket.emit('joinRoom', joinPayload);
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ الغرفة غير موجودة أو تعذر الاتصال'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FunkyBackground(
        accent: FunkyColors.magenta,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      if (widget.showBackButton)
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: FunkyColors.card,
                              border: Border.all(
                                color:
                                    FunkyColors.magenta.withValues(alpha: 0.5),
                                width: 1.3,
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          'اللعب أونلاين 🎮',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: FunkyColors.magenta
                                    .withValues(alpha: 0.7),
                                blurRadius: 14,
                              ),
                            ],
                          ).copyWith(
                              fontFamilyFallback: const ['Noto Color Emoji']),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ).animate().fadeIn(duration: 400.ms),
                      ),
                      const SizedBox(width: 42),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        // Profile summary card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration:
                              FunkyDecor.glowCard(FunkyColors.cyan, radius: 22),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: FunkyDecor.accentGradient(
                                      FunkyColors.magenta),
                                ),
                                child: SettingsService.userAvatar != null
                                    ? ClipOval(
                                        child: Image.memory(
                                          base64Decode(
                                            SettingsService.userAvatar!,
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      SettingsService.userName.isNotEmpty
                                          ? SettingsService.userName
                                          : 'لاعب مجهول',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.cairo(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'الملف الشخصي مفعل ',
                                      style: GoogleFonts.cairo(
                                        color: FunkyColors.mint,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ProfileScreen(),
                                    ),
                                  ).then((_) => setState(() {}));
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: FunkyColors.bgDeep
                                        .withValues(alpha: 0.6),
                                    border: Border.all(
                                      color: FunkyColors.cyan
                                          .withValues(alpha: 0.6),
                                      width: 1.3,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.edit_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        if (_lastRoomCode != null) ...[
                          _buildRejoinCard(),
                          const SizedBox(height: 24),
                        ],

                        Opacity(
                          opacity: _isLoading ? 0.5 : 1,
                          child: FunkyButton(
                            label: 'إنشاء غرفة جديدة',
                            accent: FunkyColors.magenta,
                            icon: Icons.add_circle_outline_rounded,
                            fontSize: 18,
                            onPressed:
                                _isLoading ? () {} : _createRoom,
                          ),
                        ),
                        const SizedBox(height: 28),

                        Row(
                          children: [
                            const Expanded(
                                child: Divider(color: Colors.white12)),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12),
                              child: Text(
                                'أو انضم لغرفة موجودة',
                                style: GoogleFonts.cairo(
                                  color: Colors.white38,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const Expanded(
                                child: Divider(color: Colors.white12)),
                          ],
                        ),

                        const SizedBox(height: 28),

                        _buildTextField(
                          controller: _roomCodeController,
                          label: 'كود الغرفة (5 أرقام)',
                          icon: Icons.numbers_rounded,
                          keyboardType: TextInputType.number,
                          letterSpacing: 8,
                          fontSize: 22,
                        ),
                        const SizedBox(height: 20),

                        Opacity(
                          opacity: _isLoading ? 0.5 : 1,
                          child: FunkyButton(
                            label: 'انضمام الآن',
                            accent: FunkyColors.mint,
                            icon: Icons.login_rounded,
                            fontSize: 18,
                            onPressed: _isLoading ? () {} : _joinRoom,
                          ),
                        ),

                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.only(top: 28),
                            child: CircularProgressIndicator(
                              color: FunkyColors.magenta,
                            ),
                          ),
                      ],
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    double? letterSpacing,
    double? fontSize,
  }) {
    return Container(
      decoration: FunkyDecor.glowCard(FunkyColors.violet, radius: 20),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textAlign: TextAlign.center,
        style: GoogleFonts.cairo(
          color: Colors.white,
          fontSize: fontSize ?? 16,
          letterSpacing: letterSpacing,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.cairo(color: Colors.white54, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.white38, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildRejoinCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: FunkyDecor.glowCard(FunkyColors.mint, radius: 20),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, color: FunkyColors.mint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'هل ترغب في العودة؟',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'غرفة $_lastRoomCode لا تزال نشطة',
                  style:
                      GoogleFonts.cairo(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _rejoinRoom,
            style: ElevatedButton.styleFrom(
              backgroundColor: FunkyColors.mint,
              foregroundColor: FunkyColors.bgDeep,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'عودة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _lastRoomCode = null),
            icon: const Icon(Icons.close, color: Colors.white38, size: 20),
          ),
        ],
      ),
    ).animate().slideX(begin: 1, end: 0).fadeIn();
  }
}
