import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shella/screens/settings_screen.dart';
import 'package:shella/services/settings_service.dart';
import 'package:shella/widgets/voice_chat_widget.dart';
import 'package:shella/widgets/reaction_overlay.dart';
import 'package:shella/services/socket_service.dart' as ss;
import 'package:shella/widgets/chat_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shella/services/audio_service.dart';
import 'package:shella/services/haptic_service.dart';
import 'package:shella/widgets/game_result_overlay.dart';
import 'package:shella/theme/funky_theme.dart';

class BaseGameScaffold extends StatefulWidget {
  final String title;
  final Widget body;
  final Color backgroundColor;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final String? roomCode; // To enable voice chat widget
  final String? myId; // To identify the user for voice chat
  final String? playerName;
  final VoidCallback? onAiRefresh;
  final bool showResultOverlay;
  final bool isWin;
  final String? resultTitle;
  final String? resultSubtitle;
  final VoidCallback? onDismissResult;
  final bool? isHost;
  final String? gameName;
  final bool showAi;

  const BaseGameScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.backgroundColor,
    this.actions,
    this.floatingActionButton,
    this.roomCode,
    this.myId,
    this.playerName,
    this.onAiRefresh,
    this.showResultOverlay = false,
    this.isWin = false,
    this.resultTitle,
    this.resultSubtitle,
    this.onDismissResult,
    this.isHost,
    this.gameName,
    this.showAi = false,
  });

  @override
  State<BaseGameScaffold> createState() => _BaseGameScaffoldState();
}

class _BaseGameScaffoldState extends State<BaseGameScaffold> {
  Map<String, dynamic>? _previewMsg;
  Timer? _previewTimer;
  StreamSubscription? _chatSub;
  StreamSubscription? _playerSub;
  int _unreadMessages = 0;
  Timer? _hostGraceTimer;

  @override
  void initState() {
    super.initState();
    // Ensure we have a room code if possible (singleton fallback)
    final effectiveRoomCode =
        widget.roomCode ?? ss.SocketService().currentRoomCode;

    if (effectiveRoomCode != null) {
      _chatSub = ss.SocketService().chatStream.listen((msg) {
        if (!mounted) return;

        // robust identification of sender to avoid self-previews
        final sender = (msg['playerName'] ?? msg['name'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final myName = (widget.playerName ?? '').trim().toLowerCase();
        final isMe = sender == myName;

        if (!ss.SocketService().isChatOpen && !isMe) {
          setState(() {
            _previewMsg = msg;
            _unreadMessages++;
          });

          _previewTimer?.cancel();
          _previewTimer = Timer(const Duration(seconds: 4), () {
            if (mounted) setState(() => _previewMsg = null);
          });
        }
      });
    }

    _playerSub = ss.SocketService().playersStream.listen((players) {
      if (!mounted) return;

      if (players.isNotEmpty) {
        final bool hostExists = players.any(
          (p) =>
              p['isHost'] == true ||
              p['isHost'] == 1 ||
              p['isHost'] == 'true' ||
              p['isHost'] == '1' ||
              p['host'] == true,
        );

        if (!hostExists) {
          _hostGraceTimer ??= Timer(const Duration(seconds: 5), () {
            if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
          });
        } else {
          if (_hostGraceTimer != null) {
            _hostGraceTimer?.cancel();
            _hostGraceTimer = null;
          }
        }
      }
    });

    // Listen for room_closed specifically for total teardown
    ss.SocketService().socket.on('room_closed', _onRoomClosed);
    ss.SocketService().socket.on('host_left', _onHostLeft);
    ss.SocketService().socket.on('game_move', _onSync);
  }

  @override
  void didUpdateWidget(BaseGameScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showResultOverlay && !oldWidget.showResultOverlay) {
      // Trigger premium feedback automatically
      if (widget.isWin) {
        AudioService.playWinVoice();
        HapticService.success();
      } else {
        AudioService.playLoseVoice();
        HapticService.heavyImpact();
      }
    }
  }

  void _onRoomClosed(dynamic data) {
    if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
  }

  void _onSync(dynamic data) {
    if (!mounted) return;
    final Map<String, dynamic> move = (data is Map && data['moveData'] != null)
        ? Map<String, dynamic>.from(data['moveData'])
        : Map<String, dynamic>.from(data);

    if (move['type'] == 'host_left_game') {
      debugPrint('BaseGameScaffold: RECEIVED host_left_game. Popping.');
      Navigator.of(context).pop();
    }
  }

  void _onHostLeft(dynamic data) {
    // Rely on player stream for grace period
  }

  void _showChat() {
    final effectiveRoomCode =
        widget.roomCode ?? ss.SocketService().currentRoomCode;
    if (effectiveRoomCode == null) return;

    setState(() {
      ss.SocketService().isChatOpen = true;
      _unreadMessages = 0;
      _previewMsg = null;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChatWidget(
        roomCode: effectiveRoomCode,
        playerName: widget.playerName ?? 'لاعب',
        initialMessages: ss.SocketService().chatMessages,
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          ss.SocketService().isChatOpen = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    _playerSub?.cancel();
    _previewTimer?.cancel();
    _hostGraceTimer?.cancel();
    ss.SocketService().socket.off('room_closed', _onRoomClosed);
    ss.SocketService().socket.off('host_left', _onHostLeft);
    ss.SocketService().socket.off('game_move', _onSync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRoomCode =
        widget.roomCode ?? ss.SocketService().currentRoomCode;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [
                FunkyColors.bgDeep.withValues(alpha: 0.92),
                widget.backgroundColor.withValues(alpha: 0.85),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: widget.backgroundColor.withValues(alpha: 0.8),
                width: 2,
              ),
            ),
          ),
        ),
        leading: widget.title.isEmpty
            ? null
            : IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white70,
                ),
                onPressed: () {
                  if (widget.isHost == true) {
                    ss.SocketService().socket.emit('game_move', {
                      'roomCode':
                          widget.roomCode ?? ss.SocketService().currentRoomCode,
                      'moveData': {
                        'type': 'host_left_game',
                        'gameName': widget.gameName ?? 'unknown',
                      },
                    });
                  }
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
        ),
        actions: [
          if (SettingsService.isAiEnabled && widget.showAi)
            IconButton(
                  icon: const Icon(
                    Icons.auto_awesome,
                    color: Colors.blueAccent,
                  ),
                  onPressed: widget.onAiRefresh ?? () {},
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .shimmer(duration: 3.seconds, color: Colors.white30)
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.1, 1.1),
                  duration: 2.seconds,
                ),
          if (effectiveRoomCode != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0, top: 4.0, bottom: 4.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 95),
                child: VoiceChatWidget(
                  roomCode: effectiveRoomCode,
                  myId:
                      widget.myId ??
                      ss.SocketService().socket.id ??
                      widget.playerName ??
                      'me',
                ),
              ),
            ),
          if (effectiveRoomCode != null)
            Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.chat_bubble_rounded,
                    color: Colors.blueAccent,
                  ),
                  onPressed: _showChat,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blueAccent.withOpacity(0.1),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
                if (_unreadMessages > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$_unreadMessages',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ...?widget.actions,
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Funky party background with accent glows
          Positioned.fill(
            child: FunkyBackground(accent: widget.backgroundColor),
          ),

          // Main Content
          SafeArea(child: widget.body),

          // Message Preview
          if (_previewMsg != null) _buildMessagePreview(_previewMsg!),

          if (effectiveRoomCode != null)
            Positioned.fill(
              child: IgnorePointer(
                child: ReactionOverlay(
                  reactionStream: ss.SocketService().reactionStream,
                ),
              ),
            ),

          if (effectiveRoomCode != null)
            Positioned(bottom: 20, right: 20, child: _EmojiPicker()),

          // Global Result Overlay
          if (widget.showResultOverlay)
            GameResultOverlay(
              isWin: widget.isWin,
              title:
                  widget.resultTitle ?? (widget.isWin ? 'مبروك!' : 'هارد لك!'),
              subtitle:
                  widget.resultSubtitle ??
                  (widget.isWin
                      ? 'لقد فزت في هذا التحدي'
                      : 'حاول مرة أخرى في الجول القادمة'),
              onDismiss: widget.onDismissResult ?? () {},
            ),
        ],
      ),

      floatingActionButton: widget.floatingActionButton,
    );
  }

  Widget _buildMessagePreview(Map<String, dynamic> msg) {
    final name = (msg['playerName'] ?? msg['name'] ?? 'لاعب').toString();
    final text = (msg['message'] ?? msg['text'] ?? '').toString();

    return Positioned(
      top: 100, // Top of the screen like a notification
      left: 20,
      right: 20,
      child:
          Center(
                child: GestureDetector(
                  onTap: _showChat,
                  child: Dismissible(
                    key: Key(
                      msg['msgId'] ??
                          msg['timestamp'] ??
                          'msg_${DateTime.now().millisecondsSinceEpoch}',
                    ),
                    direction: DismissDirection.horizontal,
                    onDismissed: (_) {
                      if (mounted) setState(() => _previewMsg = null);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF2563EB).withOpacity(0.8),
                                const Color(0xFF7C3AED).withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.cairo(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,

                                      ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      text,
                                      style: GoogleFonts.cairo(
                                        fontSize: 14,
                                        color: Colors.white.withOpacity(0.9),
                                        height: 1.1,
                                        fontWeight: FontWeight.w500,
                                      ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.swipe_right_rounded,
                                color: Colors.white24,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .animate()
              .slideY(
                begin: -1,
                end: 0,
                duration: 400.ms,
                curve: Curves.easeOutBack,
              )
              .fadeIn(duration: 300.ms)
              .shimmer(delay: 600.ms, duration: 1200.ms),
    );
  }
}

class _EmojiPicker extends StatefulWidget {
  @override
  State<_EmojiPicker> createState() => _EmojiPickerState();
}

class _EmojiPickerState extends State<_EmojiPicker> {
  bool _expanded = false;
  final List<String> _emojis = ['🔥', '😂', '😮', '💩', '👏', '❤️'];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_expanded)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _emojis
                  .map(
                    (e) => GestureDetector(
                      onTap: () {
                        ss.SocketService().emitReaction(e);
                        setState(() => _expanded = false);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(e, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ).animate().scale(alignment: Alignment.bottomRight).fadeIn(),

        FloatingActionButton.small(
          onPressed: () => setState(() => _expanded = !_expanded),
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          child: Text(
            _expanded ? '❌' : '⚡',
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ],
    );
  }
}
