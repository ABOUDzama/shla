import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/base_game_scaffold.dart';
import '../../services/socket_service.dart';
import '../../services/audio_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/funky_theme.dart';
import '../../data/most_likely_data.dart';

/// مين فينا؟ أونلاين: الكابتن يطلق سؤال، الكل يصوّت لشخص، والأصوات نقط.
class MostLikelyGameOnline extends StatefulWidget {
  final bool isHost;
  final String roomCode;
  final String? playerName;
  final List<dynamic>? roomPlayers;

  const MostLikelyGameOnline({
    super.key,
    required this.isHost,
    required this.roomCode,
    this.playerName,
    this.roomPlayers,
  });

  @override
  State<MostLikelyGameOnline> createState() => _MostLikelyGameOnlineState();
}

class _MostLikelyGameOnlineState extends State<MostLikelyGameOnline> {
  static const String _game = 'most_likely';
  final Random _rng = Random();

  String _phase = 'lobby'; // lobby, voting, results, over
  int _round = 0;
  int _totalRounds = 10;
  String _prompt = '';
  bool _voted = false;
  String? _myVote;

  final Map<String, String> _votes = {}; // voter -> target
  final Map<String, int> _totals = {};
  Map<String, int> _lastGained = {};
  final List<int> _used = [];

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
        _prompt = move['prompt']?.toString() ?? '';
        _round = move['round'] ?? 1;
        _totalRounds = move['totalRounds'] ?? 10;
        _votes.clear();
        _lastGained = {};
        _voted = false;
        _myVote = null;
        AudioService.playSuccess();
        setState(() => _phase = 'voting');
        break;
      case 'vote':
        final voter = move['voter']?.toString() ?? '';
        final target = move['target']?.toString() ?? '';
        if (voter.isNotEmpty) _votes[voter] = target;
        setState(() {});
        break;
      case 'round_end':
        _finishRound();
        break;
      case 'game_over':
        AudioService.playWinVoice();
        setState(() => _phase = 'over');
        break;
    }
  }

  void _finishRound() {
    _lastGained = {};
    for (final target in _votes.values) {
      _totals[target] = (_totals[target] ?? 0) + 1;
      _lastGained[target] = (_lastGained[target] ?? 0) + 1;
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
      idx = _rng.nextInt(mostLikelyPrompts.length);
    } while (_used.contains(idx) && _used.length < mostLikelyPrompts.length);
    _used.add(idx);
    final payload = {
      'type': 'round_start',
      'prompt': mostLikelyPrompts[idx],
      'round': _round + 1,
      'totalRounds': _totalRounds,
    };
    _emit(payload);
    payload['gameName'] = _game;
    _onMove({'moveData': payload});
  }

  void _hostEndRound() {
    if (!widget.isHost) return;
    _emit({'type': 'round_end'});
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

  void _vote(String target) {
    if (_voted) return;
    final me = widget.playerName ?? 'لاعب';
    _emit({'type': 'vote', 'voter': me, 'target': target});
    _votes[me] = target;
    AudioService.playClick();
    HapticService.lightImpact();
    setState(() {
      _voted = true;
      _myVote = target;
    });
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    return BaseGameScaffold(
      title: '👉 مين فينا؟',
      backgroundColor: FunkyColors.lime,
      roomCode: widget.roomCode,
      playerName: widget.playerName,
      body: switch (_phase) {
        'lobby' => _buildLobby(),
        'voting' => _buildVoting(),
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
            const Text('🫵', style: TextStyle(fontSize: 64))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 900.ms),
            const SizedBox(height: 12),
            Text(
              widget.isHost
                  ? 'سؤال يطلع، والكل يصوّت لمين في الشلة. كل صوت عليك = نقطة!'
                  : 'مستنيين الكابتن يبدأ السؤال...',
              textAlign: TextAlign.center,
              style: FunkyText.body(size: 17),
            ),
            const SizedBox(height: 24),
            if (widget.isHost)
              FunkyButton(
                label: 'ابدأ أول سؤال 🎬',
                accent: FunkyColors.lime,
                onPressed: _hostStartRound,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoting() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'الجولة $_round من $_totalRounds • صوّتوا: ${_votes.length}/${_playerNames.length}',
              style: FunkyText.body(size: 15, color: Colors.white.withOpacity(0.7)),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: FunkyDecor.glowCard(FunkyColors.lime),
              child: Text(
                _prompt,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.5,
                ),
              ),
            ).animate(key: ValueKey(_round)).fadeIn().scale(begin: const Offset(0.92, 0.92)),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.4,
                children: _playerNames.map((name) {
                  final isMine = _myVote == name;
                  final gotVotes = _votes.values.where((t) => t == name).length;
                  return GestureDetector(
                    onTap: _voted ? null : () => _vote(name),
                    child: Container(
                      decoration: FunkyDecor.glowCard(
                        isMine ? FunkyColors.magenta : FunkyColors.lime,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              style: FunkyText.title(size: 17, color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isMine)
                              Text('✅ صوتك', style: FunkyText.body(size: 13, color: FunkyColors.mint)),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            if (widget.isHost)
              FunkyButton(
                label: 'اعرض النتيجة 👀',
                accent: FunkyColors.magenta,
                onPressed: _hostEndRound,
              )
            else if (_voted)
              Text(
                'استنى باقي الشلة... ⏳',
                style: FunkyText.body(size: 15, color: Colors.white.withOpacity(0.7)),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    final sorted = _playerNames.toList()
      ..sort((a, b) => (_lastGained[b] ?? 0).compareTo(_lastGained[a] ?? 0));
    final top = sorted.isNotEmpty ? sorted.first : '';
    final topVotes = _lastGained[top] ?? 0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text('😂 النتيجة', style: FunkyText.headline(size: 26, color: FunkyColors.lime)),
            const SizedBox(height: 8),
            if (topVotes > 0)
              Text(
                '$top خد $topVotes صوت!',
                style: FunkyText.title(size: 20, color: Colors.white),
              )
            else
              Text('محدش اتصوّت لحد 🤷', style: FunkyText.title(size: 18)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: sorted
                    .map(
                      (n) => Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: FunkyDecor.glowCard(FunkyColors.lime, radius: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(n, style: FunkyText.title(size: 16)),
                            Text(
                              '+${_lastGained[n] ?? 0} (المجموع: ${_totals[n] ?? 0})',
                              style: FunkyText.body(size: 15, color: FunkyColors.mint),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            if (widget.isHost)
              FunkyButton(
                label: _round >= _totalRounds ? 'النتيجة النهائية 🏆' : 'السؤال اللي بعده ⏭️',
                accent: FunkyColors.lime,
                onPressed: _hostNext,
              )
            else
              Text(
                'مستنيين الكابتن...',
                style: FunkyText.body(size: 15, color: Colors.white.withOpacity(0.7)),
              ),
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
                'المتهم الأول: ${sorted.first.key}',
                style: FunkyText.headline(size: 26, color: FunkyColors.lime),
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
