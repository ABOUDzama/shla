import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/base_game_scaffold.dart';
import '../../services/socket_service.dart';
import '../../services/audio_service.dart';
import '../../services/haptic_service.dart';
import '../offline/bus_complete_game.dart';
import '../../theme/funky_theme.dart';

/// Online أتوبيس كومبليت: host drives rounds over the generic game_move
/// relay; every client scores identically from the collected answers.
class BusCompleteGameOnline extends StatefulWidget {
  final bool isHost;
  final String roomCode;
  final String? playerName;
  final List<dynamic>? roomPlayers;

  const BusCompleteGameOnline({
    super.key,
    required this.isHost,
    required this.roomCode,
    this.playerName,
    this.roomPlayers,
  });

  @override
  State<BusCompleteGameOnline> createState() => _BusCompleteGameOnlineState();
}

class _BusCompleteGameOnlineState extends State<BusCompleteGameOnline> {
  static const String _game = 'bus_complete';
  static const int _timeLimit = 60;
  final Random _rng = Random();

  String _phase = 'lobby'; // lobby, answering, submitted, results, over
  List<String> _categories = const ['ولد', 'بنت', 'جماد', 'نبات', 'بلاد', 'أكلة'];
  int _totalRounds = 3;
  int _round = 0;
  String _letter = '';
  final List<String> _usedLetters = [];
  Timer? _timer;
  int _timeLeft = _timeLimit;

  final Map<String, TextEditingController> _ctrls = {};
  final Map<String, Map<String, String>> _answers = {}; // playerName -> answers
  final Map<String, int> _totals = {};
  Map<String, int> _lastRoundScores = {};

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
    _timer?.cancel();
    SocketService().socket.off('game_move', _onMove);
    for (final c in _ctrls.values) {
      c.dispose();
    }
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
        _timer?.cancel();
        _letter = move['letter']?.toString() ?? 'ا';
        _categories = (move['categories'] as List?)?.map((e) => e.toString()).toList() ?? _categories;
        _round = move['round'] ?? 1;
        _totalRounds = move['totalRounds'] ?? 3;
        _answers.clear();
        _lastRoundScores = {};
        _ctrls.clear();
        for (final c in _categories) {
          _ctrls[c] = TextEditingController();
        }
        _timeLeft = move['timeLimit'] ?? _timeLimit;
        _startLocalTimer();
        setState(() => _phase = 'answering');
        AudioService.playSuccess();
        HapticService.lightImpact();
        break;
      case 'submit_answers':
        final name = move['playerName']?.toString() ?? 'لاعب';
        final raw = move['answers'];
        if (raw is Map) {
          _answers[name] = raw.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
        setState(() {});
        break;
      case 'round_end':
        _finishRound();
        break;
      case 'game_over':
        _timer?.cancel();
        AudioService.playWinVoice();
        setState(() => _phase = 'over');
        break;
    }
  }

  void _startLocalTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _timeLeft--);
      if (_timeLeft <= 5 && _timeLeft > 0) {
        AudioService.playTick();
      }
      if (_timeLeft <= 0) {
        t.cancel();
        if (_phase == 'answering') _submitAnswers(timeOut: true);
      }
    });
  }

  void _submitAnswers({bool timeOut = false}) {
    _timer?.cancel();
    final mine = {
      for (final c in _categories) c: _ctrls[c]?.text.trim() ?? '',
    };
    _emit({
      'type': 'submit_answers',
      'playerName': widget.playerName ?? 'لاعب',
      'answers': mine,
    });
    _answers[widget.playerName ?? 'لاعب'] = mine;
    if (timeOut) {
      AudioService.playFailure();
      HapticService.heavyImpact();
    } else {
      AudioService.playClick();
    }
    setState(() => _phase = 'submitted');
  }

  void _finishRound() {
    _timer?.cancel();
    final names = _playerNames;
    // Players who never submitted get empty answers (scored 0).
    for (final n in names) {
      _answers.putIfAbsent(n, () => {for (final c in _categories) c: ''});
    }
    _lastRoundScores = BusCompleteGame.scoreRound(names, _categories, _letter, _answers);
    for (final n in names) {
      _totals[n] = (_totals[n] ?? 0) + (_lastRoundScores[n] ?? 0);
    }
    AudioService.playSuccess();
    HapticService.success();
    setState(() => _phase = 'results');
  }

  // ---- Host actions ----

  void _hostStartRound() {
    if (!widget.isHost) return;
    String letter;
    do {
      letter = BusCompleteGame.letters[_rng.nextInt(BusCompleteGame.letters.length)];
    } while (_usedLetters.contains(letter));
    _usedLetters.add(letter);
    final next = _round + 1;
    final payload = {
      'type': 'round_start',
      'letter': letter,
      'categories': _categories,
      'round': next,
      'totalRounds': _totalRounds,
      'timeLimit': _timeLimit,
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

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    return BaseGameScaffold(
      title: 'أتوبيس كومبليت 🚌',
      backgroundColor: FunkyColors.coral,
      roomCode: widget.roomCode,
      playerName: widget.playerName,
      body: switch (_phase) {
        'lobby' => _buildLobby(),
        'answering' => _buildAnswering(),
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
            Text('🚌', style: const TextStyle(fontSize: 64))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveX(begin: -10, end: 10, duration: 1100.ms),
            const SizedBox(height: 12),
            Text(
              widget.isHost
                  ? 'إنت الكابتن! هيتحسب لكل واحد 10 نقط للإجابة المختلفة و5 للمكررة.'
                  : 'مستنيين الكابتن يبدأ الجولة...',
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
                label: Text('ابدأ الجولة 1 🚀', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ] else
              const CircularProgressIndicator(color: Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswering() {
    final urgent = _timeLeft <= 10;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.orange,
                radius: 26,
                child: Text(_letter,
                    style: GoogleFonts.cairo(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('الجولة $_round / $_totalRounds',
                    style: GoogleFonts.cairo(color: Colors.white70, fontSize: 15)),
              ),
              Text('$_timeLeft',
                  style: GoogleFonts.cairo(
                      color: urgent ? Colors.redAccent : Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        LinearProgressIndicator(
          value: (_timeLeft / _timeLimit).clamp(0.0, 1.0),
          backgroundColor: Colors.white12,
          color: urgent ? Colors.redAccent : Colors.orange,
          minHeight: 5,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final c in _categories)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: _ctrls[c],
                    textAlign: TextAlign.right,
                    style: GoogleFonts.cairo(color: Colors.white, fontSize: 17),
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: c,
                      labelStyle: GoogleFonts.cairo(color: Colors.orange.shade200),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.07),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.orange),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _submitAnswers(),
              icon: const Icon(Icons.send),
              label: Text('خلصت! ✅', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitted() {
    final total = _playerNames.length;
    final done = _answers.length;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⏳', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 12),
          Text(
            'إجابتك وصلت! $done / $total خلصوا',
            style: GoogleFonts.cairo(color: Colors.white70, fontSize: 17),
          ),
          const SizedBox(height: 20),
          if (widget.isHost)
            ElevatedButton.icon(
              onPressed: _hostEndRound,
              icon: const Icon(Icons.flag),
              label: Text('قفل الجولة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final names = _playerNames.isEmpty ? _answers.keys.toList() : _playerNames;
    final sorted = names.toList()
      ..sort((a, b) => (_lastRoundScores[b] ?? 0).compareTo(_lastRoundScores[a] ?? 0));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text('نتايج جولة "$_letter"',
              style: GoogleFonts.cairo(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          for (final cat in _categories) _categoryResult(cat, names),
          const SizedBox(height: 12),
          for (final p in sorted)
            ListTile(
              dense: true,
              title: Text(p, style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
              trailing: Text('+${_lastRoundScores[p] ?? 0}  (المجموع: ${_totals[p] ?? 0})',
                  style: GoogleFonts.cairo(color: Colors.greenAccent, fontSize: 13)),
            ),
          const SizedBox(height: 10),
          if (widget.isHost)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _hostNext,
                icon: Icon(_round >= _totalRounds ? Icons.emoji_events : Icons.skip_next),
                label: Text(
                  _round >= _totalRounds ? 'النتيجة النهائية 🏆' : 'الجولة الجاية ▶️',
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

  Widget _categoryResult(String cat, List<String> names) {
    final normalized = <String, String>{};
    final counts = <String, int>{};
    for (final p in names) {
      final raw = _answers[p]?[cat] ?? '';
      final norm = BusCompleteGame.normalize(raw).toLowerCase();
      normalized[p] = norm;
      if (norm.isNotEmpty && BusCompleteGame.startsWithLetter(raw, _letter)) {
        counts[norm] = (counts[norm] ?? 0) + 1;
      }
    }
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
          Text(cat, style: GoogleFonts.cairo(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          for (final p in names)
            Builder(builder: (_) {
              final raw = _answers[p]?[cat] ?? '';
              final norm = normalized[p] ?? '';
              final valid = norm.isNotEmpty && BusCompleteGame.startsWithLetter(raw, _letter);
              final dup = valid && (counts[norm] ?? 0) > 1;
              final pts = !valid ? 0 : (dup ? 5 : 10);
              return Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(p, style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(
                    child: Text(
                      raw.isEmpty ? '—' : raw,
                      style: GoogleFonts.cairo(
                        color: valid ? Colors.white : Colors.red.shade300,
                        fontSize: 13,
                        decoration: valid ? null : TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                  Text('+$pts',
                      style: GoogleFonts.cairo(
                        color: pts == 10 ? Colors.greenAccent : (pts == 5 ? Colors.amber : Colors.white38),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      )),
                ],
              );
            }),
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
            Text(iWon ? '🏆' : '🚌💨', style: const TextStyle(fontSize: 72)),
            const SizedBox(height: 10),
            Text(
              names.isEmpty ? 'خلصت اللعبة!' : 'الكابتن: ${names.first}!',
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
