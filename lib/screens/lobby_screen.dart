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
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    if (widget.showBackButton)
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        'اللعب أونلاين 🎮',
                        style: GoogleFonts.cairo(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,

                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Profile Summary Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(13),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    FunkyColors.magenta,
                                    FunkyColors.violet,
                                  ],
                                ),
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
                                      size: 30,
                                    ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    SettingsService.userName.isNotEmpty
                                        ? SettingsService.userName
                                        : 'لاعب مجهول',
                                    style: GoogleFonts.cairo(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'الملف الشخصي مفعل ',
                                    style: GoogleFonts.cairo(
                                      color: const Color(0xFF22C55E),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ProfileScreen(),
                                  ),
                                ).then((_) => setState(() {}));
                              },
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.indigoAccent,
                              ),
                              tooltip: 'تعديل الملف الشخصي',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      if (_lastRoomCode != null) ...[
                        _buildRejoinCard(),
                        const SizedBox(height: 24),
                      ],

                      // Create room button
                      _buildButton(
                        label: 'إنشاء غرفة جديدة',
                        icon: Icons.add_circle_outline_rounded,
                        gradient: const LinearGradient(
                          colors: [FunkyColors.magenta, FunkyColors.violet],
                        ),
                        onTap: _isLoading ? null : _createRoom,
                      ),
                      const SizedBox(height: 32),

                      Row(
                        children: [
                          const Expanded(child: Divider(color: Colors.white12)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'أو انضم لغرفة موجودة',
                              style: GoogleFonts.cairo(
                                color: Colors.white38,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider(color: Colors.white12)),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Room code field
                      _buildTextField(
                        controller: _roomCodeController,
                        label: 'كود الغرفة (5 أرقام)',
                        icon: Icons.numbers_rounded,
                        keyboardType: TextInputType.number,
                        letterSpacing: 8,
                        fontSize: 22,
                      ),
                      const SizedBox(height: 24),

                      // Join room button
                      _buildButton(
                        label: 'انضمام الآن',
                        icon: Icons.login_rounded,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F9B8E), Color(0xFF14B8A6)],
                        ),
                        onTap: _isLoading ? null : _joinRoom,
                      ),

                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: 32),
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
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textAlign: TextAlign.center,
        style: GoogleFonts.cairo(
          color: Colors.white,
          fontSize: fontSize ?? 16,

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

  Widget _buildButton({
    required String label,
    required IconData icon,
    required LinearGradient gradient,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: double.infinity,
          height: 64,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withAlpha(80),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRejoinCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withValues(alpha: 0.15),
            Colors.teal.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, color: Colors.greenAccent),
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
                  style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _rejoinRoom,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Flexible(
              child: Text(
                'عودة',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
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
