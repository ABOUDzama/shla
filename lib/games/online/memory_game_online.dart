import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/base_game_scaffold.dart';
import '../../services/socket_service.dart';
import '../../services/audio_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/funky_theme.dart';

/// ذاكرة الشلة أونلاين: بورد مشترك، كل لاعب يقلب كارتين في دوره.
/// كل الأجهزة بتحسب الماتش بنفس المنطق فمفيش حاجة بتتبعت غير القلبات.
class MemoryGameOnline extends StatefulWidget {
  final bool isHost;
  final String roomCode;
  final String? playerName;
  final List<dynamic>? roomPlayers;

  const MemoryGameOnline({
    super.key,
    required this.isHost,
    required this.roomCode,
    this.playerName,
    this.roomPlayers,
  });

  @override
  State<MemoryGameOnline> createState() => _MemoryGameOnlineState();
}

class _MemoryGameOnlineState extends State<MemoryGameOnline> {
  static const String _game = 'memory_match';
  static const List<String> _emojiPool = [
    '🍕', '🚀', '🎸', '🐱', '🌈', '⚽', '🎁', '🍉',
    '🐸', '👑', '🎯', '🚗', '🍩', '🦁', '🎨', '⭐',
  ];
  static const int pairCount = 8;

  String _phase = 'lobby'; // lobby, playing, over
  List<String> _board = [];
  List<String> _order = [];
  final Set<int> _matched = {};
  int? _firstPick;
  int _turn = 0;
  bool _busy = false;
  final Map<String, int> _scores = {};
  Timer? _flipBackTimer;

  List<String> get _playerNames => (widget.roomPlayers ?? const [])
      .map((p) => (p['name'] ?? 'لاعب').toString())
      .toList();

  String get _currentPlayer =>
      _order.isEmpty ? '' : _order[_turn % _order.length];

  bool get _myTurn => _currentPlayer == (widget.playerName ?? '');

  @override
  void initState() {
    super.initState();
    SocketService().socket.on('game_move', _onMove);
  }

  @override
  void dispose() {
    _flipBackTimer?.cancel();
    SocketService().socket.off('game_move', _onMove);
    super.dispose();
  }

  void _emit(Map<String, dynamic> moveData) {
    moveData['gameName'] = _game;
    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });
  }

  void _onMove(dynamic data) {
    if (!mounted) return;
    final move = (data is Map && data['moveData'] != null)
        ? Map<String, dynamic>.from(data['moveData'])
        : Map<String, dynamic>.from(data);
    if (move['gameName'] != _game) return;

    switch (move['type']) {
      case 'board_init':
        _board =
            (move['board'] as List?)?.map((e) => e.toString()).toList() ?? [];
        _order =
            (move['order'] as List?)?.map((e) => e.toString()).toList() ?? [];
        _matched.clear();
        _firstPick = null;
        _turn = 0;
        _busy = false;
        _scores.clear();
        AudioService.playSuccess();
        setState(() => _phase = 'playing');
        break;
      case 'flip':
        final idx = move['index'];
        if (idx is int) _applyFlip(idx, remote: true);
        break;
    }
  }

  void _applyFlip(int index, {required bool remote}) {
    if (_phase != 'playing' || _busy) return;
    if (_matched.contains(index) || index == _firstPick) return;
    HapticService.lightImpact();
    setState(() {
      if (_firstPick == null) {
        _firstPick = index;
        return;
      }
      final first = _firstPick!;
      _firstPick = null;
      if (_board[first] == _board[index]) {
        _matched.addAll([first, index]);
        _scores[_currentPlayer] = (_scores[_currentPlayer] ?? 0) + 1;
        AudioService.playSuccess();
        HapticService.success();
        if (_matched.length == _board.length) {
          AudioService.playWinVoice();
          _phase = 'over';
        }
      } else {
        _busy = true;
        AudioService.playClick();
        _flipBackTimer?.cancel();
        _flipBackTimer = Timer(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          setState(() {
            _turn++;
            _busy = false;
          });
        });
      }
    });
  }

  void _flip(int index) {
    if (!_myTurn || _busy || _matched.contains(index) || index == _firstPick) {
      return;
    }
    _emit({'type': 'flip', 'index': index});
    _applyFlip(index, remote: false);
  }

  // ---- Host ----

  void _hostStart() {
    if (!widget.isHost) return;
    final emojis = ([..._emojiPool]..shuffle(_rng())).take(pairCount).toList();
    final board = [...emojis, ...emojis]..shuffle(Random());
    final order = List<String>.from(_playerNames)..shuffle(Random());
    if (order.isEmpty) return;
    final payload = {'type': 'board_init', 'board': board, 'order': order};
    _emit(payload);
    payload['gameName'] = _game;
    _onMove({'moveData': payload});
  }

  Random _rng() => Random();

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    return BaseGameScaffold(
      title: '🧠 ذاكرة الشلة',
      backgroundColor: FunkyColors.sky,
      roomCode: widget.roomCode,
      playerName: widget.playerName,
      body: switch (_phase) {
        'lobby' => _buildLobby(),
        'playing' => _buildPlaying(),
        _ => _buildGameOver(),
      },
    );
  }

  Widget _buildLobby() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🃏', style: TextStyle(fontSize: 64))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 900.ms),
            const SizedBox(height: 12),
            Text(
              widget.isHost
                  ? 'بورد واحد لكل الشلة! اقلب كارتين في دورك، المتشابه ليك وتكمل.'
                  : 'مستنيين الكابتن يوزع الكروت...',
              textAlign: TextAlign.center,
              style: FunkyText.body(size: 17),
            ),
            const SizedBox(height: 24),
            if (widget.isHost)
              FunkyButton(
                label: 'وزع الكروت 🎬',
                accent: FunkyColors.sky,
                onPressed: _hostStart,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaying() {
    final accent = FunkyColors
        .accents[_order.indexOf(_currentPlayer).clamp(0, 9) % FunkyColors.accents.length];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: FunkyDecor.pill(accent),
              child: Text(
                _myTurn ? 'دورك! اقلب كارتين 👆' : 'دور: $_currentPlayer',
                style: FunkyText.title(size: 15, color: Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: _order
                  .map(
                    (n) => Text(
                      '$n: ${_scores[n] ?? 0}',
                      style: FunkyText.body(
                        size: 14,
                        color: n == _currentPlayer
                            ? accent
                            : Colors.white.withOpacity(0.6),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.count(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                physics: const NeverScrollableScrollPhysics(),
                children: List.generate(_board.length, (i) {
                  final shown = _matched.contains(i) || i == _firstPick;
                  return GestureDetector(
                    onTap: () => _flip(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      decoration: shown
                          ? FunkyDecor.glowCard(
                              _matched.contains(i) ? FunkyColors.mint : accent,
                              radius: 14,
                            )
                          : BoxDecoration(
                              color: FunkyColors.cardLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: FunkyColors.violet.withOpacity(0.5),
                                width: 1.2,
                              ),
                            ),
                      child: Center(
                        child: Text(
                          shown ? _board[i] : '❓',
                          style: TextStyle(fontSize: shown ? 34 : 22),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOver() {
    final sorted = _scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topScore = sorted.isEmpty ? 0 : sorted.first.value;
    final winners = sorted.where((e) => e.value == topScore).toList();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🧠🏆', style: TextStyle(fontSize: 70))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 800.ms),
            const SizedBox(height: 12),
            Text(
              winners.length == 1
                  ? 'الذاكرة الحديدية: ${winners.first.key}'
                  : 'تعادل أذكياء! 🤝',
              style: FunkyText.headline(size: 24, color: FunkyColors.sky),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ...sorted.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text('${e.key} — ${e.value} زوج', style: FunkyText.body(size: 17)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
