import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/base_game_scaffold.dart';
import '../../services/socket_service.dart';
import '../../services/audio_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/funky_theme.dart';
import '../../data/emoji_guess_data.dart';
import '../offline/bus_complete_game.dart' show BusCompleteGame;

/// إيموجي إيه؟ أونلاين: الكابتن يطلق كارت إيموجي، الكل يكتب تخمينه،
/// أول تخمين صح ياخد النقطة (المقارنة بتتعمل عند الكابتن).
class EmojiGuessGameOnline extends StatefulWidget {
  final bool isHost;
  final String roomCode;
  final String? playerName;
  final List<dynamic>? roomPlayers;

  const EmojiGuessGameOnline({
    super.key,
    required this.isHost,
    required this.roomCode,
    this.playerName,
    this.roomPlayers,
  });

  @override
  State<EmojiGuessGameOnline> createState() => _EmojiGuessGameOnlineState();
}

class _EmojiGuessGameOnlineState extends State<EmojiGuessGameOnline> {
  static const String _game = 'emoji_guess';
  final Random _rng = Random();

  String _phase = 'lobby'; // lobby, guessing, results, over
  int _round = 0;
  int _totalRounds = 10;
  String _emojis = '';
  String _category = '';
  String _answer = '';
  String? _winner;
  bool _submitted = false;

  final List<Map<String, String>> _guesses = []; // host-side: {name, text}
  final Map<String, int> _totals = {};
  final List<int> _used = [];
  final TextEditingController _guessCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    SocketService().socket.on('game_move', _onMove);
  }

  @override
  void dispose() {
    _guessCtrl.dispose();
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
      case 'round_start':
        _emojis = move['emojis']?.toString() ?? '';
        _category = move['category']?.toString() ?? '';
        _round = move['round'] ?? 1;
        _totalRounds = move['totalRounds'] ?? 10;
        if (widget.isHost) {
          _answer = move['answer']?.toString() ?? '';
        }
        _winner = null;
        _guesses.clear();
        _submitted = false;
        _guessCtrl.clear();
        AudioService.playSuccess();
        setState(() => _phase = 'guessing');
        break;
      case 'guess':
        if (!widget.isHost) return;
        final name = move['playerName']?.toString() ?? 'لاعب';
        final text = move['text']?.toString() ?? '';
        if (text.isEmpty) return;
        setState(() => _guesses.add({'name': name, 'text': text}));
        if (_winner == null &&
            BusCompleteGame.normalizeForCompare(text) ==
                BusCompleteGame.normalizeForCompare(_answer)) {
          _declareWinner(name);
        }
        break;
      case 'round_end':
        _winner = move['winner']?.toString();
        _answer = move['answer']?.toString() ?? '';
        if (move['totals'] is Map) {
          _totals
            ..clear()
            ..addAll((move['totals'] as Map)
                .map((k, v) => MapEntry(k.toString(), (v as num).toInt())));
        }
        AudioService.playSuccess();
        HapticService.success();
        setState(() => _phase = 'results');
        break;
      case 'game_over':
        AudioService.playWinVoice();
        setState(() => _phase = 'over');
        break;
    }
  }

  // ---- Host ----

  void _hostStartRound() {
    if (!widget.isHost) return;
    int idx;
    do {
      idx = _rng.nextInt(emojiGuessCards.length);
    } while (_used.contains(idx) && _used.length < emojiGuessCards.length);
    _used.add(idx);
    final card = emojiGuessCards[idx];
    _answer = card.answer;
    final payload = {
      'type': 'round_start',
      'emojis': card.emojis,
      'category': card.category,
      'answer': card.answer,
      'round': _round + 1,
      'totalRounds': _totalRounds,
    };
    _emit(payload);
    payload['gameName'] = _game;
    _onMove({'moveData': payload});
  }

  void _declareWinner(String? name) {
    if (name != null) {
      _totals[name] = (_totals[name] ?? 0) + 1;
    }
    final payload = {
      'type': 'round_end',
      'winner': name,
      'answer': _answer,
      'totals': _totals,
    };
    _emit(payload);
    payload['gameName'] = _game;
    _onMove({'moveData': payload});
  }

  void _hostNoWinner() => _declareWinner(null);

  void _hostNext() {
    if (!widget.isHost) return;
    if (_round >= _totalRounds) {
      _emit({'type': 'game_over'});
      AudioService.playWinVoice();
      setState(() => _phase = 'over');
    } else {
      _hostStartRound();
    }
  }

  void _submitGuess() {
    final text = _guessCtrl.text.trim();
    if (text.isEmpty || _submitted) return;
    _emit({
      'type': 'guess',
      'playerName': widget.playerName ?? 'لاعب',
      'text': text,
    });
    AudioService.playClick();
    setState(() => _submitted = true);
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    return BaseGameScaffold(
      title: '🧩 إيموجي إيه؟',
      backgroundColor: FunkyColors.amber,
      roomCode: widget.roomCode,
      playerName: widget.playerName,
      body: switch (_phase) {
        'lobby' => _buildLobby(),
        'guessing' => _buildGuessing(),
        'results' => _buildResults(),
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
            const Text('🤔', style: TextStyle(fontSize: 64))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 900.ms),
            const SizedBox(height: 12),
            Text(
              widget.isHost
                  ? 'إيموجي يطلع، والكل يكتب تخمينه. أول واحد يجيب صح ياخد النقطة!'
                  : 'مستنيين الكابتن يبدأ أول كارت...',
              textAlign: TextAlign.center,
              style: FunkyText.body(size: 17),
            ),
            const SizedBox(height: 24),
            if (widget.isHost)
              FunkyButton(
                label: 'ابدأ أول كارت 🎬',
                accent: FunkyColors.amber,
                onPressed: _hostStartRound,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuessing() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'الجولة $_round من $_totalRounds',
              style: FunkyText.body(size: 15, color: Colors.white.withOpacity(0.7)),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: FunkyDecor.glowCard(FunkyColors.amber),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: FunkyDecor.pill(FunkyColors.sky),
                    child: Text(_category,
                        style: FunkyText.body(size: 14, color: Colors.white)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _emojis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 58, height: 1.3),
                  ).animate(key: ValueKey(_round)).fadeIn().scale(begin: const Offset(0.8, 0.8)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!widget.isHost) ...[
              TextField(
                controller: _guessCtrl,
                enabled: !_submitted,
                textAlign: TextAlign.center,
                style: FunkyText.title(size: 18, color: Colors.white),
                decoration: InputDecoration(
                  hintText: _submitted ? 'تخمينك اتبعت ✅' : 'اكتب تخمينك هنا...',
                  hintStyle: FunkyText.body(
                      size: 15, color: Colors.white.withOpacity(0.45)),
                  filled: true,
                  fillColor: FunkyColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _submitGuess(),
              ),
              const SizedBox(height: 12),
              FunkyButton(
                label: _submitted ? 'مستنيين النتيجة...' : 'ابعت تخمينك 🚀',
                accent: FunkyColors.amber,
                onPressed: _submitted ? null : _submitGuess,
              ),
            ] else ...[
              Expanded(
                child: _guesses.isEmpty
                    ? Center(
                        child: Text(
                          'مستني تخمينات الشلة... 👀',
                          style: FunkyText.body(
                              size: 16, color: Colors.white.withOpacity(0.7)),
                        ),
                      )
                    : ListView(
                        children: _guesses
                            .map(
                              (g) => Container(
                                margin: const EdgeInsets.symmetric(vertical: 3),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: FunkyDecor.glowCard(FunkyColors.amber, radius: 14),
                                child: Text(
                                  '${g['name']}: ${g['text']}',
                                  style: FunkyText.body(size: 15),
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
              FunkyButton(
                label: 'محدش عرف 😅 اعرض الإجابة',
                accent: FunkyColors.coral,
                onPressed: _hostNoWinner,
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _emojis,
              style: const TextStyle(fontSize: 54),
            ),
            const SizedBox(height: 12),
            Text(
              _answer,
              style: GoogleFonts.cairo(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: FunkyColors.mint,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _winner != null ? '🎉 $_winner خمّن صح!' : 'محدش خمّنها 😅',
              style: FunkyText.title(size: 20, color: FunkyColors.amber),
            ),
            const SizedBox(height: 16),
            ..._totals.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('${e.key} — ${e.value} نقطة',
                    style: FunkyText.body(size: 16)),
              ),
            ),
            const SizedBox(height: 16),
            if (widget.isHost)
              FunkyButton(
                label: _round >= _totalRounds ? 'النتيجة النهائية 🏆' : 'الكارت اللي بعده ⏭️',
                accent: FunkyColors.amber,
                onPressed: _hostNext,
              )
            else
              Text(
                'مستنيين الكابتن...',
                style: FunkyText.body(size: 15, color: Colors.white.withOpacity(0.7)),
              ),
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
                'عبقري الإيموجي: ${sorted.first.key}',
                style: FunkyText.headline(size: 26, color: FunkyColors.amber),
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
