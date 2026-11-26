import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../games/online/xo_game_online.dart';
import '../games/online/seega_game_online.dart';
import '../games/online/gobblet_game_online.dart';
import '../games/online/quiz_game_online.dart';
import '../games/online/tick_tock_boom_online.dart';
import '../games/online/multi_touch_screen_online.dart';
import '../games/online/balance_game_online.dart';
import '../games/online/five_seconds_game_online.dart';
import '../games/online/reverse_quiz_online.dart';
import '../games/online/odd_one_out_online.dart';
import '../games/online/first_letter_game_online.dart';
import '../games/online/opposite_day_online.dart';
import '../games/online/who_am_i_game_online.dart';
import '../games/online/word_chain_game_online.dart';
import '../games/online/truth_or_dare_game_online.dart';
import '../games/online/pictionary_game_online.dart';
import '../games/online/charades_game_online.dart';
import '../games/online/truth_or_lie_game_online.dart';
import '../games/online/bus_complete_game_online.dart';
import '../games/online/most_likely_game_online.dart';
import '../games/online/taboo_game_online.dart';
import '../games/online/memory_game_online.dart';
import '../games/online/emoji_guess_game_online.dart';
import '../games/online/ranking_challenge_game_online.dart';
import '../services/socket_service.dart' as ss;
import '../services/haptic_service.dart';
import '../widgets/voice_chat_widget.dart';
import '../widgets/chat_widget.dart';
import '../widgets/player_avatar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import '../services/voice_chat_service.dart';
import '../widgets/reaction_overlay.dart';
import '../theme/flat_theme.dart';

class RoomScreen extends StatefulWidget {
  final String roomCode;
  final bool isHost;
  final String playerName;
  final String? avatarBase64;

  const RoomScreen({
    super.key,
    required this.roomCode,
    required this.isHost,
    required this.playerName,
    this.avatarBase64,
  });

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _players = [];
  int _unreadMessages = 0;
  bool _isNavigating = false;
  StreamSubscription? _playerSub;
  StreamSubscription? _chatSub;
  Map<String, dynamic>? _previewMsg;
  Timer? _previewTimer;
  Timer? _hostGraceTimer;
  bool _isExitingExplicitly = false;
  StreamSubscription? _speakingSub;
  bool _anybodySpeaking = false;
  Timer? _autoSyncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Don't reset messages here, they are kept in SocketService for the session
    // Reset messages and players for the new room entry
    _unreadMessages = 0;

    // Always start with only the current player when entering a room to avoid ghosts
    _players = [
      {
        'name': widget.playerName,
        'avatar': widget.avatarBase64,
        'isHost': widget.isHost,
        'id': ss.SocketService().socket.id,
      },
    ];

    // Set room context for centralized re-joining and chat
    ss.SocketService().setRoomContext(
      widget.roomCode,
      widget.playerName,
      avatar: widget.avatarBase64,
    );

    _playerSub = ss.SocketService().playersStream.listen((updatedPlayers) {
      if (!mounted) return;
      setState(() {
        _players = List.from(updatedPlayers);

        // Host Exit Logic: If I am not host, check if host is still present
        if (!widget.isHost && _players.isNotEmpty) {
          final bool hostExists = _players.any(
            (p) =>
                p['isHost'] == true ||
                p['isHost'] == 1 ||
                p['isHost'] == 'true' ||
                p['isHost'] == '1',
          );

          if (!hostExists) {
            // Host is missing, start grace period if not already running
            _hostGraceTimer ??= Timer(const Duration(seconds: 5), () {
              if (mounted) {
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            });
          } else {
            // Host is back! Cancel timer
            if (_hostGraceTimer != null) {
              _hostGraceTimer?.cancel();
              _hostGraceTimer = null;
            }
          }
        }
      });
    });

    ss.SocketService().socket.on('game_selected', _onGameSelected);
    ss.SocketService().socket.on('player_left', _onPlayerLeft);
    ss.SocketService().socket.on('room_closed', _onRoomClosed);
    ss.SocketService().socket.on('player_returned_msg', _onPlayerReturnedMsg);

    _chatSub = ss.SocketService().chatStream.listen((msg) {
      if (!mounted) return;

      // robust identification of sender to avoid self-previews if server echoes back
      final sender = (msg['playerName'] ?? msg['name'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final isMe = sender == widget.playerName.trim().toLowerCase();

      if (!ss.SocketService().isChatOpen && !isMe) {
        setState(() {
          _unreadMessages++;
          _previewMsg = msg;
        });

        _previewTimer?.cancel();
        _previewTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() => _previewMsg = null);
          }
        });
      }
    });

    // Auto-sync mechanism (every 60 seconds)
    if (!ss.SocketService.isTesting)
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted && ss.SocketService().isConnected) {
        ss.SocketService().forceRoomSync();
        if (VoiceChatService().isInitialized) {
          VoiceChatService().makeCall(
            widget.roomCode,
            (ss.SocketService().socket.id ?? '').toString(),
          );
        }
      }
    });

    _speakingSub = VoiceChatService().speakingStream.listen((ids) {
      if (!mounted) return;
      final bool someoneSpeaking = ids.isNotEmpty;
      if (someoneSpeaking != _anybodySpeaking) {
        setState(() => _anybodySpeaking = someoneSpeaking);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('RoomScreen: Lifecycle Resumed - Syncing Socket & Voice');
      ss.SocketService().revalidateSession();

      // Production fix: Mobile OS often kills WebRTC tracks when backgrounded
      if (VoiceChatService().isInitialized) {
        VoiceChatService().resetAndRetry(widget.roomCode);
      }
    }
  }

  void _onGameSelected(dynamic data) {
    if (!mounted) return;
    _navigateToGame(data['gameName']);
  }

  void _onPlayerLeft(dynamic data) {
    // Silence is golden, as requested
  }

  void _onRoomClosed(dynamic data) {
    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  void _onPlayerReturnedMsg(dynamic data) {
    // Silence is golden, as requested
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playerSub?.cancel();
    _chatSub?.cancel();
    _previewTimer?.cancel();
    _autoSyncTimer?.cancel();
    _hostGraceTimer?.cancel();
    _speakingSub?.cancel();

    ss.SocketService().socket.off('game_selected', _onGameSelected);
    ss.SocketService().socket.off('player_left', _onPlayerLeft);
    ss.SocketService().socket.off('room_closed', _onRoomClosed);
    ss.SocketService().socket.off('player_returned_msg', _onPlayerReturnedMsg);

    // Clean up communication services
    VoiceChatService().dispose();

    // Only clear context if explicitly exiting or not host
    if (_isExitingExplicitly || !widget.isHost) {
      ss.SocketService().clearRoomContext();
    }
    super.dispose();
  }

  void _selectGame(String gameName) {
    if (_isNavigating) return;
    if (_players.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('انتظر انضمام لاعب آخر على الأقل')),
      );
      return;
    }
    ss.SocketService().socket.emit('select_game', {
      'roomCode': widget.roomCode,
      'gameName': gameName,
    });
  }

  void _navigateToGame(String gameName) async {
    if (_isNavigating) return;
    _isNavigating = true;

    try {
      Widget? gameScreen;
      switch (gameName) {
        case 'xo':
          gameScreen = TicTacToeGameOnline(
            isHost: widget.isHost,
            roomCode: widget.roomCode,
            playerName: widget.playerName,
            roomPlayers: _players,
          );
          break;
        case 'seega':
        case 'Seega':
          gameScreen = SeegaGameOnline(
            isHost: widget.isHost,
            roomCode: widget.roomCode,
            playerName: widget.playerName,
            roomPlayers: _players,
          );
          break;
        case 'gobblet':
        case 'Gobblet':
          gameScreen = GobbletGameOnline(
            isHost: widget.isHost,
            roomCode: widget.roomCode,
            playerName: widget.playerName,
            roomPlayers: _players,
          );
          break;
        case 'quiz':
          gameScreen = QuizGameOnline(
            isHost: widget.isHost,
            roomCode: widget.roomCode,
            playerName: widget.playerName,
            roomPlayers: _players,
          );
          break;
        case 'multi_touch':
          gameScreen = MultiTouchScreenOnline(
            isHost: widget.isHost,
            roomCode: widget.roomCode,
            playerName: widget.playerName,
            roomPlayers: _players,
          );
          break;
        case 'balance_game':
          gameScreen = BalanceGameOnline(
            isHost: widget.isHost,
            roomCode: widget.roomCode,
            playerName: widget.playerName,
            roomPlayers: _players,
          );
          break;
        case 'five_seconds':
          gameScreen = FiveSecondsGameOnline(
            isHost: widget.isHost,
            roomCode: widget.roomCode,
            playerName: widget.playerName,
            roomPlayers: _players,
          );
          break;
        case 'reverse_quiz':
          gameScreen = ReverseQuizOnline(
            isHost: widget.isHost,
            roomCode: widget.roomCode,
            playerName: widget.playerName,
            roomPlayers: _players,
          );
          break;
        case 'odd_one_out':
          gameScreen = OddOneOutOnline(
            isHost: widget.isHost,
            roomCode: widget.roomCode,
            playerName: widget.playerName,
            roomPlayers: _players,
          );
          break;
        case 'first_letter':
          gameScreen = FirstLetterGameOnline(
            isHost: widget.isHost,
            roomCode: widget.roomCode,
            playerName: widget.playerName,
            roomPlayers: _players,
          );
          break;
        case 'opposite_game':
          gameScreen = OppositeDayOnline(
            isHost: widget.isHost,
            roomCode: widget.roomCode,
            playerName: widget.playerName,
            roomPlayers: _players,
          );
          break;
        case 'who_am_i':
          gameScreen = WhoAmIGameOnline(
            isHost: widget.isHost,
            roomCode: widget.roomCode,
            playerName: widget.playerName,
            roomPlayers: _players,
          );
          break;
        case 'word_chain':
          gameScreen = WordChainGameOnline(
            isHost: widget.isHost,
            roomCode: widget.roomCode,
            playerName: widget.playerName,
            roomPlayers: _players,
          );
          break;
        case 'truth_or_dare':
          gameScreen = TruthOrDareGameOnline(
            isHost: widget.isHost,
            roomCode: widget.roomCode,
            playerName: widget.playerName,
            roomPlayers: _players,
          );
          break;
        case 'pictionary':
          gameScreen = PictionaryGameOnline(
            isHost: widget.isHost,
            roomCode: widget.roomCode,
            playerName: widget.playerName,
            roomPlayers: _players,
          );
          break;
        case 'charades':
          gameScreen = CharadesGameOnline(
            isHost: widget.isHost,
            roomCode: widget.roomCode,
            playerName: widget.playerName,
            roomPlayers: _players,
          );
          break;
        case 'truth_or_lie':
          gameScreen = TruthOrLieGameOnline(
            isHost: widget.isHost,
            roomCode: widget.roomCode,
            playerName: widget.playerName,
            roomPlayers: _players,
          );
          break;
        case 'tick_tock_boom':
          gameScreen = TickTockBoomOnline(
            isHost: widget.isHost,
            roomCode: widget.roomCode,
            playerName: widget.playerName,
            roomPlayers: _players,
          );
          break;
        case 'ranking_challenge':
          gameScreen = RankingChallengeGameOnline(
            isHost: widget.isHost,
            roomCode: widget.roomCode,
            playerName: widget.playerName,
            roomPlayers: _players,
          );
          break;
        case 'bus_complete':
          gameScreen = BusCompleteGameOnline(
            isHost: widget.isHost,
            roomCode: widget.roomCode,
            playerName: widget.playerName,
            roomPlayers: _players,
          );
          break;
        case 'most_likely':
          gameScreen = MostLikelyGameOnline(
            isHost: widget.isHost,
            roomCode: widget.roomCode,
            playerName: widget.playerName,
            roomPlayers: _players,
          );
          break;
        case 'taboo':
          gameScreen = TabooGameOnline(
            isHost: widget.isHost,
            roomCode: widget.roomCode,
            playerName: widget.playerName,
            roomPlayers: _players,
          );
          break;
        case 'memory_match':
          gameScreen = MemoryGameOnline(
            isHost: widget.isHost,
            roomCode: widget.roomCode,
            playerName: widget.playerName,
            roomPlayers: _players,
          );
          break;
        case 'emoji_guess':
          gameScreen = EmojiGuessGameOnline(
            isHost: widget.isHost,
            roomCode: widget.roomCode,
            playerName: widget.playerName,
            roomPlayers: _players,
          );
          break;
        default:
          return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => gameScreen!),
      );

      if (mounted) {
        final me = _players.firstWhere(
          (p) => p['id'] == ss.SocketService().socket.id,
          orElse: () => {'name': widget.playerName},
        );
        ss.SocketService().socket.emit('player_returned', {
          'roomCode': widget.roomCode,
          'playerName': me['name'],
        });
      }
    } finally {
      _isNavigating = false;
    }
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.roomCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ الكود! 📋'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isReady = _players.length >= 2;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final bool? shouldClose = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: Text(
              'مغادرة الغرفة',
              style: flatCairo(color: FlatColors.ink),
            ),
            content: Text(
              widget.isHost
                  ? 'هل تريد إغلاق الغرفة نهائياً أم إبقائها مفتوحة للآخرين؟'
                  : 'هل أنت متأكد من مغادرة الغرفة؟',
              style: flatCairo(color: FlatColors.ink.withValues(alpha: 0.75)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'إلغاء',
                  style: flatCairo(color: FlatColors.ink.withValues(alpha: 0.55)),
                ),
              ),
              if (widget.isHost)
                TextButton(
                  onPressed: () {
                    _isExitingExplicitly =
                        false; // Just navigate away, keep room
                    Navigator.pop(context, true);
                  },
                  child: Text(
                    'إبقاء مفتوحة',
                    style: flatCairo(color: FlatColors.playerBlue),
                  ),
                ),
              TextButton(
                onPressed: () {
                  _isExitingExplicitly = true; // Close for real
                  // Notify others immediately
                  ss.SocketService().socket.emit('close_room', {
                    'roomCode': widget.roomCode,
                  });
                  Navigator.pop(context, true);
                },
                child: Text(
                  widget.isHost ? 'إغلاق الغرفة' : 'مغادرة',
                  style: flatCairo(color: FlatColors.playerRed),
                ),
              ),
            ],
          ),
        );

        if (shouldClose == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: FlatColors.bg,
        body: Stack(
            children: [
              SafeArea(
              child: Column(
                  children: [
                    StreamBuilder<bool>(
                      stream: Stream.periodic(
                        const Duration(seconds: 2),
                        (_) => ss.SocketService().isConnected,
                      ),
                      initialData: ss.SocketService().isConnected,
                      builder: (context, snapshot) {
                        final bool connected = snapshot.data ?? true;
                        if (connected) return const SizedBox.shrink();
                        return Container(
                          width: double.infinity,
                          color: Colors.red.withAlpha(200),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'جاري استعادة الاتصال.. 🔄',
                                style: flatCairo(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    _buildHeader(),
                    Expanded(
                      // Bottom inset keeps the scroll viewport above the
                      // floating emoji picker (bottom: 20, ~64px tall), so
                      // no content is ever hidden behind it at any scroll
                      // position, not only when scrolled to the end.
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 100),
                        child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _buildRoomCodeCard(),
                            const SizedBox(height: 28),
                            Row(
                              children: [
                                Icon(
                                  Icons.people_alt_rounded,
                                  color: FlatColors.ink.withValues(alpha: 0.5),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'اللاعبون (${_players.length})',
                                    style: flatCairo(
                                      color: FlatColors.ink.withValues(alpha: 0.55),
                                      fontSize: 15,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!isReady)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration:
                                        FlatDecor.button(FlatColors.tilePastels[4], radius: 20),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(
                                          width: 10,
                                          height: 10,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: FlatColors.ink,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'بانتظار لاعبين',
                                          style: flatCairo(
                                            color: FlatColors.ink,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration:
                                        FlatDecor.button(FlatColors.tilePastels[2], radius: 20),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: FlatColors.ink,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'جاهز للبدء',
                                          style: flatCairo(
                                            color: FlatColors.ink,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            RepaintBoundary(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: _players
                                    .map((p) => _buildPlayerCard(p))
                                    .toList(),
                              ),
                            ),
                            if (_players.isEmpty || _players.length == 1)
                              _buildEmptySlot(),
                            const SizedBox(height: 32),
                            Text(
                              widget.isHost
                                  ? (isReady
                                        ? '🎮 اختر اللعبة لتبدأ:'
                                        : '🎮 ستظهر الألعاب بعد انضمام لاعب آخر')
                                  : '🎮 الألعاب المتاحة (في انتظار اختيار المضيف):',
                              style: flatCairo(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: isReady
                                    ? FlatColors.ink
                                    : FlatColors.ink.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 16),
                            RepaintBoundary(
                              child: GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisSpacing: 20,
                                mainAxisSpacing: 20,
                                childAspectRatio: 0.82,
                                children: [
                                  _GameCard(
                                    title: 'إكس أو',
                                    emoji: '❌⭕',
                                    color: FlatColors.tilePastels[2],
                                    onTap: (isReady && widget.isHost)
                                        ? () => _selectGame('xo')
                                        : null,
                                  ),
                                  _GameCard(
                                    title: 'سيجَا',
                                    emoji: '♟️',
                                    color: FlatColors.tilePastels[3],
                                    onTap: (isReady && widget.isHost)
                                        ? () => _selectGame('seega')
                                        : null,
                                  ),
                                  _GameCard(
                                    title: 'الكبير ياكل',
                                    emoji: '🔴🔵',
                                    color: FlatColors.tilePastels[0],
                                    onTap: (isReady && widget.isHost)
                                        ? () => _selectGame('gobblet')
                                        : null,
                                  ),
                                  _GameCard(
                                    title: 'خمس ثواني',
                                    emoji: '⏱️',
                                    color: FlatColors.tilePastels[5],
                                    onTap: (isReady && widget.isHost)
                                        ? () => _selectGame('five_seconds')
                                        : null,
                                  ),
                                  _GameCard(
                                    title: 'ارسم وخمّن',
                                    emoji: '🎨',
                                    color: FlatColors.tilePastels[1],
                                    onTap: (isReady && widget.isHost)
                                        ? () => _selectGame('pictionary')
                                        : null,
                                  ),
                                  _GameCard(
                                    title: 'حقيقة أم جرأة',
                                    emoji: '😈',
                                    color: FlatColors.tilePastels[5],
                                    onTap: (isReady && widget.isHost)
                                        ? () => _selectGame('truth_or_dare')
                                        : null,
                                  ),
                                  _GameCard(
                                    title: 'تحدي التعريف',
                                    emoji: '⏱️',
                                    color: FlatColors.tilePastels[2],
                                    onTap: (isReady && widget.isHost)
                                        ? () => _selectGame('word_chain')
                                        : null,
                                  ),
                                  _GameCard(
                                    title: 'أول حرف',
                                    emoji: '🔤',
                                    color: FlatColors.tilePastels[3],
                                    onTap: (isReady && widget.isHost)
                                        ? () => _selectGame('first_letter')
                                        : null,
                                  ),
                                  _GameCard(
                                    title: 'قنبلة الحروف',
                                    emoji: '💣',
                                    color: FlatColors.tilePastels[3],
                                    onTap: (isReady && widget.isHost)
                                        ? () => _selectGame('tick_tock_boom')
                                        : null,
                                  ),
                                  _GameCard(
                                    title: 'تحدي الأسئلة',
                                    emoji: '🧠',
                                    color: FlatColors.tilePastels[4],
                                    onTap: (isReady && widget.isHost)
                                        ? () => _selectGame('quiz')
                                        : null,
                                  ),
                                  _GameCard(
                                    title: 'مين أنا؟',
                                    emoji: '🎭',
                                    color: FlatColors.tilePastels[1],
                                    onTap: (isReady && widget.isHost)
                                        ? () => _selectGame('who_am_i')
                                        : null,
                                  ),
                                  _GameCard(
                                    title: 'تحدي الترتيب',
                                    emoji: '🎯',
                                    color: FlatColors.tilePastels[3],
                                    onTap: (isReady && widget.isHost)
                                        ? () => _selectGame('ranking_challenge')
                                        : null,
                                  ),
                                  _GameCard(
                                    title: 'أتوبيس كومبليت',
                                    emoji: '🚌',
                                    color: FlatColors.tilePastels[4],
                                    onTap: (isReady && widget.isHost)
                                        ? () => _selectGame('bus_complete')
                                        : null,
                                  ),
                                  _GameCard(
                                    title: 'مين فينا؟',
                                    emoji: '🫵',
                                    color: FlatColors.tilePastels[2],
                                    onTap: (isReady && widget.isHost)
                                        ? () => _selectGame('most_likely')
                                        : null,
                                  ),
                                  _GameCard(
                                    title: 'كلمات ممنوعة',
                                    emoji: '🙊',
                                    color: FlatColors.tilePastels[3],
                                    onTap: (isReady && widget.isHost)
                                        ? () => _selectGame('taboo')
                                        : null,
                                  ),
                                  _GameCard(
                                    title: 'ذاكرة الشلة',
                                    emoji: '🧠',
                                    color: FlatColors.tilePastels[1],
                                    onTap: (isReady && widget.isHost)
                                        ? () => _selectGame('memory_match')
                                        : null,
                                  ),
                                  _GameCard(
                                    title: 'إيموجي إيه؟',
                                    emoji: '🧩',
                                    color: FlatColors.tilePastels[4],
                                    onTap: (isReady && widget.isHost)
                                        ? () => _selectGame('emoji_guess')
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                            // Clearance for the floating emoji picker
                            // (bottom: 20, ~64px tall) so it never overlaps
                            // the last content when fully scrolled.
                            const SizedBox(height: 110),
                          ],
                        ),
                      ),
                      ),
                    ),
                  ],
                ),
              ),
            // Floating Reaction UI
            Positioned(bottom: 20, right: 20, child: _EmojiPicker()),
            // Reaction Overlay (Flying Emojis)
            Positioned.fill(
              child: IgnorePointer(
                child: ReactionOverlay(
                  reactionStream: ss.SocketService().reactionStream,
                ),
              ),
            ),
            ],
        ),
      ),
    );
  }

  void _showChat() {
    setState(() {
      ss.SocketService().isChatOpen = true;
      _unreadMessages = 0;
    });
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChatWidget(
        roomCode: widget.roomCode,
        playerName: widget.playerName,
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: FlatDecor.card(radius: 22),
        child: Row(
          children: [
            // Back Button
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: FlatColors.border,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: FlatColors.ink,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'غرفة الانتظار 🛋️',
                style: flatCairo(
                  color: FlatColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Communication Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                VoiceChatWidget(
                  roomCode: widget.roomCode,
                  myId: ss.SocketService().socket.id ?? widget.playerName,
                ),
                const SizedBox(width: 8),
                Stack(
                  alignment: Alignment.topRight,
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: _showChat,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: FlatColors.border,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.forum_rounded,
                          color: FlatColors.playerBlue,
                          size: 18,
                        ),
                      ),
                    ),
                    if (_unreadMessages > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: FlatColors.playerRed,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 1.5,
                            ),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$_unreadMessages',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    if (_previewMsg != null)
                      _buildMessagePreview(_previewMsg!),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagePreview(Map<String, dynamic> msg) {
    final name = msg['playerName'] ?? msg['name'] ?? 'لاعب';
    final text = msg['message'] ?? '';

    return Positioned(
      right: 35, // Positioned to the left of the chat button
      top: -10, // Slightly above
      child:
          Dismissible(
                key: Key(
                  msg['msgId'] ??
                      msg['timestamp'] ??
                      'msg_${DateTime.now().millisecondsSinceEpoch}',
                ),
                direction: DismissDirection.horizontal,
                onDismissed: (_) {
                  if (mounted) setState(() => _previewMsg = null);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  constraints: const BoxConstraints(maxWidth: 160),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: FlatColors.border, width: 2),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: flatCairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: FlatColors.playerBlue,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        text,
                        style: flatCairo(
                          fontSize: 13,
                          color: FlatColors.ink,
                          height: 1.2,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              )
              .animate()
              .fadeIn()
              .slideX(begin: 0.3, end: 0)
              .scale(alignment: Alignment.bottomRight),
    );
  }

  Widget _buildRoomCodeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: FlatDecor.card(radius: 24),
      child: Column(
        children: [
          Text(
            'كود الغرفة',
            style: flatCairo(
                color: FlatColors.ink.withValues(alpha: 0.6),
                fontSize: 14),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.roomCode,
              style: flatCairo(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                color: FlatColors.ink,
                letterSpacing: 10,
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _copyCode,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration:
                  FlatDecor.button(FlatColors.tilePastels[0], radius: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.copy_rounded,
                    color: FlatColors.ink,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'انسخ الكود وشاركه مع أصحابك',
                      style: flatCairo(
                        color: FlatColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(Map<String, dynamic> player) {
    // Fail-safe for production: ignore malformed player data during rapid syncs
    if (player['name'] == null) return const SizedBox.shrink();

    final bool isMe = player['id'] == ss.SocketService().socket.id;
    final bool isHost = player['isHost'] == true;
    var b64 = player['avatar'] as String?;
    if (b64 != null && b64.contains(',')) {
      b64 = b64.split(',').last.trim();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isMe
              ? FlatColors.tilePastels[5]
              : FlatColors.border,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          PlayerAvatar(
            name: player['name'] ?? 'لاعب',
            avatar: b64,
            playerId: player['id']?.toString(),
            size: 48,
            enableSpeakingIndicator: true,
            isHost: isHost,
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player['name'] as String? ?? 'لاعب',
                        style: flatCairo(
                          color: FlatColors.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(أنت)',
                        style: flatCairo(
                          color: FlatColors.mintDark,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
                if (isHost)
                  Text(
                    'مضيف',
                    style: flatCairo(
                        color: const Color(0xFF9C6E00), fontSize: 12),
                  ),
              ],
            ),
          ),
          const Icon(Icons.circle, color: FlatColors.mintDark, size: 12),
        ],
      ),
    );
  }

  Widget _buildEmptySlot() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FlatColors.border, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: FlatColors.bg,
              border: Border.all(
                color: FlatColors.border,
                width: 2,
              ),
            ),
            child: Icon(
              Icons.person_add_rounded,
              color: FlatColors.ink.withValues(alpha: 0.3),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'بانتظار لاعب...',
            style: flatCairo(
                color: FlatColors.ink.withValues(alpha: 0.35),
                fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ─── Game Card Widget ───────────────────────────────────
class _GameCard extends StatelessWidget {
  final String title;
  final String emoji;
  final Color color;
  final VoidCallback? onTap;

  const _GameCard({
    required this.title,
    required this.emoji,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onTap == null;

    return GestureDetector(
      onTap: () {
        if (!isDisabled) {
          HapticService.vibrate(duration: 40);
          onTap!();
        }
      },
      child: AnimatedOpacity(
        opacity: isDisabled ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          decoration: FlatDecor.card(radius: 24),
          child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Flat solid pastel emoji disc
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: Text(
                                  emoji,
                                  style: const TextStyle(
                                    fontSize: 40,
                                  ), // Increased font size since FittedBox will scale it down if needed
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: flatCairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: FlatColors.ink,
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                  color: FlatColors.border,
                  width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _emojis
                  .map(
                    (e) => GestureDetector(
                      onTap: () {
                        HapticService.lightImpact();
                        ss.SocketService().emitReaction(e);
                        if (mounted) setState(() => _expanded = false);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(e, style: const TextStyle(fontSize: 32)),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ).animate().scale(alignment: Alignment.bottomRight).fadeIn(),

        GestureDetector(
          onTap: () {
            HapticService.vibrate(duration: 30);
            setState(() => _expanded = !_expanded);
          },
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: FlatColors.tilePastels[0],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _expanded ? '❌' : '⚡',
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
