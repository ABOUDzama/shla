import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/base_game_scaffold.dart';
import '../../services/socket_service.dart';
import '../../services/audio_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/funky_theme.dart';
import '../../data/taboo_data.dart';

/// كلمات ممنوعة أونلاين: واصف بياخد الكارت على جهازه (باقي الشلة مش شايفاه)،
/// والكابتن بيحسب النقط. كل لاعب ليه دورين.
class TabooGameOnline extends StatefulWidget {
  final bool isHost;
  final String roomCode;
  final String? playerName;
  final List<dynamic>? roomPlayers;

  const TabooGameOnline({
    super.key,
    required this.isHost,
    required this.roomCode,
    this.playerName,
    this.roomPlayers,
  });

  @override
  State<TabooGameOnline> createState() => _TabooGameOnlineState();
}

class _TabooGameOnlineState extends State<TabooGameOnline> {
  static const String _game = 'taboo';
  static const int secondsPerTurn = 60;
  static const int turnsPerPlayer = 2;
  final Random _rng = Random();

  String _phase = 'lobby'; // lobby, turn, over
  int _turnsPlayed = 0;
  int _describerIndex = 0;
  String _describer = '';
  String _word = '';
  List<String> _forbidden = [];
  int _secondsLeft = secondsPerTurn;
  Timer? _timer;

  final Map<String, int> _totals = {};
  final List<int> _usedCards = [];
  int _currentCardIdx = 0;

  List<String> get _playerNames => (widget.roomPlayers ?? const [])
      .map((p) => (p['name'] ?? 'لاعب').toString())
      .toList();

  int get _totalTurns => _playerNames.length * turnsPerPlayer;

  @override
  void initState() {
    super.initState();
    SocketService().socket.on('game_move', _onMove);
  }

  @override
  void dispose() {
    _timer?.cancel();
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

  int _drawCard() {
    int idx;
    do {
      idx = _rng.nextInt(tabooCards.length);
    } while (_usedCards.contains(idx) && _usedCards.length < tabooCards.length);
    _usedCards.add(idx);
    return idx;
  }

  void _onMove(dynamic data) {
    if (!mounted) return;
    final move = (data is Map && data['moveData'] != null)
        ? Map<String, dynamic>.from(data['moveData'])
        : Map<String, dynamic>.from(data);
    if (move['gameName'] != _game) return;

    switch (move['type']) {
      case 'turn_start':
      case 'card_next':
        _describer = move['describer']?.toString() ?? '';
        _describerIndex = move['describerIndex'] ?? 0;
        _word = move['word']?.toString() ?? '';
        _forbidden =
            (move['forbidden'] as List?)?.map((e) => e.toString()).toList() ?? [];
        _turnsPlayed = move['turnsPlayed'] ?? _turnsPlayed;
        if (move['type'] == 'turn_start') {
          _startLocalTimer();
          AudioService.playSuccess();
        } else {
          AudioService.playClick();
        }
        setState(() => _phase = 'turn');
        break;
      case 'score':
        final name = move['name']?.toString() ?? '';
        _totals[name] = move['total'] ?? (_totals[name] ?? 0);
        setState(() {});
        break;
      case 'game_over':
        _timer?.cancel();
        AudioService.playWinVoice();
        setState(() => _phase = 'over');
        break;
    }
  }

  void _startLocalTimer() {
    _timer?.cancel();
    _secondsLeft = secondsPerTurn;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 5 && _secondsLeft > 0) AudioService.playTick();
        if (_secondsLeft <= 0) {
          _timer?.cancel();
          if (widget.isHost) _hostNextTurn();
        }
      });
    });
  }

  void _sendCard({required bool newTurn}) {
    _currentCardIdx = _drawCard();
    final card = tabooCards[_currentCardIdx];
    final payload = {
      'type': newTurn ? 'turn_start' : 'card_next',
      'describer': _describer,
      'describerIndex': _describerIndex,
      'word': card.word,
      'forbidden': card.forbidden,
      'turnsPlayed': _turnsPlayed,
    };
    _emit(payload);
    payload['gameName'] = _game;
    _onMove({'moveData': payload});
  }

  // ---- Host ----

  void _hostStart() {
    if (!widget.isHost || _playerNames.isEmpty) return;
    _turnsPlayed = 0;
    _describerIndex = 0;
    _describer = _playerNames.first;
    _sendCard(newTurn: true);
  }

  void _hostGuessed() {
    if (!widget.isHost) return;
    _totals[_describer] = (_totals[_describer] ?? 0) + 1;
    _emit({'type': 'score', 'name': _describer, 'total': _totals[_describer]});
    AudioService.playSuccess();
    HapticService.success();
    _sendCard(newTurn: false);
  }

  void _hostSkip() {
    if (!widget.isHost) return;
    AudioService.playClick();
    _sendCard(newTurn: false);
  }

  void _hostNextTurn() {
    if (!widget.isHost) return;
    _timer?.cancel();
    _turnsPlayed++;
    if (_turnsPlayed >= _totalTurns) {
      _emit({'type': 'game_over'});
      AudioService.playWinVoice();
      setState(() => _phase = 'over');
      return;
    }
    _describerIndex = (_describerIndex + 1) % _playerNames.length;
    _describer = _playerNames[_describerIndex];
    _sendCard(newTurn: true);
  }

  // ---- UI ----

  bool get _isDescriber => (widget.playerName ?? '') == _describer;

  @override
  Widget build(BuildContext context) {
    return BaseGameScaffold(
      title: '🚫 كلمات ممنوعة',
      backgroundColor: FunkyColors.coral,
      roomCode: widget.roomCode,
      playerName: widget.playerName,
      body: switch (_phase) {
        'lobby' => _buildLobby(),
        'turn' => _buildTurn(),
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
            const Text('🙊', style: TextStyle(fontSize: 64))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 900.ms),
            const SizedBox(height: 12),
            Text(
              widget.isHost
                  ? 'كل واحد يوصف كروت في 60 ثانية من غير الكلمات الممنوعة. كل كلمة صح = نقطة!'
                  : 'مستنيين الكابتن يبدأ...',
              textAlign: TextAlign.center,
              style: FunkyText.body(size: 17),
            ),
            const SizedBox(height: 24),
            if (widget.isHost)
              FunkyButton(
                label: 'ابدأ اللعب 🎬',
                accent: FunkyColors.coral,
                onPressed: _hostStart,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurn() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: FunkyDecor.pill(FunkyColors.violet),
                  child: Text('الواصف: $_describer',
                      style: FunkyText.title(size: 15, color: Colors.white)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: FunkyDecor.pill(
                      _secondsLeft <= 10 ? FunkyColors.coral : FunkyColors.mint),
                  child: Text('⏱ $_secondsLeft',
                      style: FunkyText.title(size: 16, color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_isDescriber || widget.isHost)
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: FunkyDecor.glowCard(FunkyColors.coral),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _word,
                        style: GoogleFonts.cairo(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ).animate(key: ValueKey(_word)).fadeIn().slideY(begin: -0.2),
                      const SizedBox(height: 14),
                      Text('🙊 ممنوع تقول:',
                          style: FunkyText.title(size: 15, color: FunkyColors.amber)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: _forbidden
                            .map(
                              (w) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: FunkyDecor.pill(FunkyColors.magenta),
                                child: Text(w,
                                    style: FunkyText.body(size: 14, color: Colors.white)),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('👂', style: TextStyle(fontSize: 64))
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 800.ms),
                      const SizedBox(height: 12),
                      Text(
                        '$_describer بيوصف... خمّنوا بسرعة!',
                        style: FunkyText.title(size: 20, color: FunkyColors.coral),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if (widget.isHost) ...[
              Row(
                children: [
                  Expanded(
                    child: FunkyButton(
                      label: 'تخطي ⏭️',
                      accent: FunkyColors.amber,
                      onPressed: _hostSkip,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FunkyButton(
                      label: 'خمّنوها! +1 ✅',
                      accent: FunkyColors.mint,
                      onPressed: _hostGuessed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FunkyButton(
                label: 'إنهاء الدور 🛑',
                accent: FunkyColors.coral,
                onPressed: _hostNextTurn,
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOver() {
    final sorted = _totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 72))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.12, 1.12), duration: 800.ms),
            const SizedBox(height: 12),
            if (sorted.isNotEmpty)
              Text(
                'أحسن واصف: ${sorted.first.key}',
                style: FunkyText.headline(size: 26, color: FunkyColors.coral),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 16),
            ...sorted.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text('${e.key} — ${e.value} نقطة', style: FunkyText.body(size: 17)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
