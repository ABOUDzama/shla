import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/base_game_scaffold.dart';
import '../../services/socket_service.dart';
import '../../services/audio_service.dart';
import '../../services/haptic_service.dart';
import '../offline/ranking_challenge_game.dart';
import '../../data/ranking_challenge_data.dart';

/// Online تحدي الترتيب: the host picks a deck, players submit their secret
/// orders, and the host reveals the true order at round end. Every client
/// scores identically with RankingChallengeGame.scoreGuess.
class RankingChallengeGameOnline extends StatefulWidget {
  final bool isHost;
  final String roomCode;
  final String? playerName;
  final List<dynamic>? roomPlayers;

  const RankingChallengeGameOnline({
    super.key,
    required this.isHost,
    required this.roomCode,
    this.playerName,
    this.roomPlayers,
  });

  @override
  State<RankingChallengeGameOnline> createState() => _RankingChallengeGameOnlineState();
}

class _RankingChallengeGameOnlineState extends State<RankingChallengeGameOnline> {
  static const String _game = 'ranking_challenge';
  final Random _rng = Random();

  String _phase = 'lobby'; // lobby, guessing, submitted, results, over
  int _totalRounds = 3;
  int _round = 0;
  String _topic = '';
  String _icon = '🔢';
  List<String> _shuffled = [];
  List<String> _truth = [];
  List<String> _guess = [];

  final Map<String, List<String>> _guesses = {};
  final Map<String, int> _totals = {};
  Map<String, int> _lastScores = {};
  final List<int> _usedDecks = [];

  List<String> get _playerNames => (widget.roomPlayers ?? const [])
      .map((p) => (p['name'] ?? 'لاعب').toString())
      .toList();

  @override
  void initState() {
    super.initState();
    SocketService().socket.on('game_move', _onMove);
  }

  @override
  void dispose() {
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
        _topic = move['topic']?.toString() ?? '';
        _icon = move['icon']?.toString() ?? '🔢';
        _shuffled = (move['items'] as List?)?.map((e) => e.toString()).toList() ?? [];
        _round = move['round'] ?? 1;
        _totalRounds = move['totalRounds'] ?? 3;
        _guesses.clear();
        _lastScores = {};
        _guess = List<String>.from(_shuffled);
        AudioService.playSuccess();
        setState(() => _phase = 'guessing');
        break;
      case 'submit_order':
        final name = move['playerName']?.toString() ?? 'لاعب';
        final g = move['guess'];
        if (g is List) {
          _guesses[name] = g.map((e) => e.toString()).toList();
        }
        setState(() {});
        break;
      case 'round_end':
        _truth = (move['truth'] as List?)?.map((e) => e.toString()).toList() ?? [];
        _finishRound();
        break;
      case 'game_over':
        AudioService.playWinVoice();
        setState(() => _phase = 'over');
        break;
    }
  }

  void _finishRound() {
    final names = _playerNames.isEmpty ? _guesses.keys.toList() : _playerNames;
    _lastScores = {};
    for (final n in names) {
      final g = _guesses[n];
      final s = (g == null || _truth.isEmpty) ? 0 : RankingChallengeGame.scoreGuess(g, _truth);
      _lastScores[n] = s;
      _totals[n] = (_totals[n] ?? 0) + s;
    }
    AudioService.playSuccess();
    HapticService.success();
    setState(() => _phase = 'results');
  }

  // ---- Host ----

  void _hostStartRound() {
    if (!widget.isHost) return;
    int idx;
    do {
      idx = _rng.nextInt(rankingChallengeDecks.length);
    } while (_usedDecks.contains(idx) && _usedDecks.length < rankingChallengeDecks.length);
    _usedDecks.add(idx);
    final deck = rankingChallengeDecks[idx];
    _truth = List<String>.from(deck['items']);
    final shuffled = List<String>.from(_truth)..shuffle(_rng);
    final payload = {
      'type': 'round_start',
      'topic': deck['topic'],
      'icon': deck['icon'],
      'items': shuffled,
      'round': _round + 1,
      'totalRounds': _totalRounds,
    };
    _emit(payload);
    payload['gameName'] = _game;
    _onMove({'moveData': payload});
  }

  void _hostEndRound() {
    if (!widget.isHost) return;
    _emit({'type': 'round_end', 'truth': _truth});
    _finishRound();
  }

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

  void _submit() {
    _emit({
      'type': 'submit_order',
      'playerName': widget.playerName ?? 'لاعب',
      'guess': _guess,
    });
    _guesses[widget.playerName ?? 'لاعب'] = List<String>.from(_guess);
    AudioService.playClick();
    setState(() => _phase = 'submitted');
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    return BaseGameScaffold(
      title: 'تحدي الترتيب 🔢',
      backgroundColor: const Color(0xFF6A1B9A),
      roomCode: widget.roomCode,
      playerName: widget.playerName,
      body: switch (_phase) {
        'lobby' => _buildLobby(),
        'guessing' => _buildGuessing(),
        'submitted' => _buildSubmitted(),
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
            const Text('🧠', style: TextStyle(fontSize: 64))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 900.ms),
            const SizedBox(height: 12),
            Text(
              widget.isHost
                  ? 'رتّب العناصر صح واكسب: 3 نقط للمكان المظبوط ونقطة لو جنبه.'
                  : 'مستنيين الكابتن يختار التحدي...',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(color: Colors.white70, fontSize: 15, height: 1.6),
            ),
            const SizedBox(height: 16),
            if (widget.isHost) ...[
              Text('عدد الجولات', style: GoogleFonts.cairo(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 6),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 3, label: Text('3')),
                  ButtonSegment(value: 5, label: Text('5')),
                ],
                selected: {_totalRounds},
                onSelectionChanged: (s) => setState(() => _totalRounds = s.first),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _hostStartRound,
                icon: const Icon(Icons.play_arrow_rounded, size: 28),
                label: Text('ابدأ التحدي 🚀', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ] else
              const CircularProgressIndicator(color: Color(0xFFBA68C8)),
          ],
        ),
      ),
    );
  }

  Widget _buildGuessing() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF6A1B9A).withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFBA68C8).withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Text(_icon, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_topic,
                    style: GoogleFonts.cairo(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              Text('جولة $_round/$_totalRounds',
                  style: GoogleFonts.cairo(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ),
        Text('اسحب ورتّب من الأول للأخير', style: GoogleFonts.cairo(color: Colors.white54, fontSize: 13)),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _guess.length,
            onReorder: (oldIdx, newIdx) {
              HapticService.lightImpact();
              setState(() {
                if (newIdx > oldIdx) newIdx--;
                final item = _guess.removeAt(oldIdx);
                _guess.insert(newIdx, item);
              });
            },
            itemBuilder: (context, i) => Container(
              key: ValueKey(_guess[i]),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF6A1B9A),
                  child: Text('${i + 1}', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: Text(_guess[i], style: GoogleFonts.cairo(color: Colors.white, fontSize: 16)),
                trailing: const Icon(Icons.drag_indicator, color: Colors.white38),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.send),
              label: Text('ثبت الترتيب ✅', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitted() {
    final total = _playerNames.length;
    final done = _guesses.length;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⏳', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 12),
          Text('ترتيبك اتبعت! $done / $total خلصوا',
              style: GoogleFonts.cairo(color: Colors.white70, fontSize: 17)),
          const SizedBox(height: 20),
          if (widget.isHost)
            ElevatedButton.icon(
              onPressed: _hostEndRound,
              icon: const Icon(Icons.visibility),
              label: Text('اكشف الترتيب الصح', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final names = _lastScores.keys.toList()
      ..sort((a, b) => (_lastScores[b] ?? 0).compareTo(_lastScores[a] ?? 0));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text('الترتيب الصح ✅',
              style: GoogleFonts.cairo(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                for (int i = 0; i < _truth.length; i++)
                  Row(
                    children: [
                      SizedBox(
                        width: 26,
                        child: Text('${i + 1}',
                            style: GoogleFonts.cairo(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                      ),
                      Expanded(child: Text(_truth[i], style: GoogleFonts.cairo(color: Colors.white, fontSize: 14))),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final n in names)
            _playerResultTile(n),
          const SizedBox(height: 12),
          if (widget.isHost)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _hostNext,
                icon: Icon(_round >= _totalRounds ? Icons.emoji_events : Icons.skip_next),
                label: Text(
                  _round >= _totalRounds ? 'النتيجة النهائية 🏆' : 'التحدي الجاي ▶️',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                ),
              ),
            )
          else
            Text('مستنيين الكابتن...', style: GoogleFonts.cairo(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _playerResultTile(String name) {
    final g = _guesses[name] ?? const <String>[];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontWeight: name == widget.playerName ? FontWeight.w900 : FontWeight.bold)),
              ),
              Text('+${_lastScores[name] ?? 0}',
                  style: GoogleFonts.cairo(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Text('المجموع: ${_totals[name] ?? 0}',
                  style: GoogleFonts.cairo(color: Colors.white54, fontSize: 12)),
            ],
          ),
          if (g.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (int i = 0; i < g.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: i < _truth.length && _truth[i] == g[i]
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.red.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${i + 1}. ${g[i]}',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: i < _truth.length && _truth[i] == g[i] ? Colors.greenAccent : Colors.red.shade200,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGameOver() {
    final names = _totals.keys.toList()
      ..sort((a, b) => (_totals[b] ?? 0).compareTo(_totals[a] ?? 0));
    final medals = ['🥇', '🥈', '🥉'];
    final iWon = names.isNotEmpty && names.first == (widget.playerName ?? '');
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(iWon ? '🏆' : '🧠', style: const TextStyle(fontSize: 72)),
            const SizedBox(height: 10),
            Text(
              names.isEmpty ? 'خلصت اللعبة!' : 'أدق واحد: ${names.first}!',
              style: GoogleFonts.cairo(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 20),
            for (int i = 0; i < names.length; i++)
              ListTile(
                leading: Text(i < 3 ? medals[i] : '${i + 1}', style: const TextStyle(fontSize: 20)),
                title: Text(names[i],
                    style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontWeight: names[i] == widget.playerName ? FontWeight.w900 : FontWeight.normal)),
                trailing: Text('${_totals[names[i]]} نقطة', style: GoogleFonts.cairo(color: Colors.white70)),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.door_back_door_outlined),
              label: Text('ارجع للغرفة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
