import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/audio_service.dart';
import '../../theme/flat_theme.dart';
import '../../theme/funky_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import '../../services/player_names.dart';
import 'rhythm_logic.dart';
import 'rhythm_mic.dart';

/// تحدّي الإيقاع 👏 — the phone plays a short clap pattern, every player
/// takes a turn imitating it (claps at the mic, or taps in the clearly
/// labeled tap mode). The pattern gets longer and faster each level; the
/// most accurate timing wins. 1-4 players; solo is practice (no winner, no
/// recorded result).
class RhythmGame extends StatefulWidget {
  const RhythmGame({
    super.key,
    this.randomSeed,
    this.nowMs,
    this.maxLevels = 5,
    this.micDetectorFactory,
  });

  /// Fixed RNG seed for deterministic tests; null uses a live random source.
  final int? randomSeed;

  /// Injectable clock (ms) so tests control timing. Defaults to wall clock.
  final int Function()? nowMs;

  /// Level count; tests shorten the match through this.
  final int maxLevels;

  /// Overrides the mic detector in tests. Null builds the real mic detector.
  final ClapDetector Function()? micDetectorFactory;

  @override
  State<RhythmGame> createState() => _RhythmGameState();
}

enum _RhythmPhase {
  pickPlayers,
  pickMode,
  turnIntro,
  watching,
  listening,
  turnResult,
  levelResult,
  over,
}

class _RhythmGameState extends State<RhythmGame> {
  static const _emojiFallback = ['Noto Color Emoji'];
  static const List<Color> _colors = [
    Color(0xFFFF8A5C),
    Color(0xFF4D8DFF),
    Color(0xFF35C99E),
    Color(0xFFFF6FA5),
  ];

  bool _showIntro = true;
  _RhythmPhase _phase = _RhythmPhase.pickPlayers;

  late final RhythmGenerator _gen =
      RhythmGenerator(seed: widget.randomSeed);
  late final int Function() _now =
      widget.nowMs ?? () => DateTime.now().millisecondsSinceEpoch;

  int _players = 2;
  bool _useMic = true;
  bool _micFailed = false;
  int _level = 1;
  int _turn = 0;
  RhythmPattern _pattern = const RhythmPattern([400, 400]);
  List<int> _totals = [];
  final List<int> _onsets = [];
  int _watchIndex = -1;
  int _listenStart = 0;
  RhythmScore? _lastScore;
  bool _listeningFlash = false;

  final List<Timer> _timers = [];
  Timer? _listenTimer;
  ClapDetector? _detector;

  int get _listenWindowMs => _pattern.totalMs + 1500;

  @override
  void dispose() {
    _cancelTimers();
    _detector?.stop();
    super.dispose();
  }

  void _cancelTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    _listenTimer?.cancel();
    _listenTimer = null;
  }

  // -- flow ---------------------------------------------------------------

  void _pickPlayers(int n) {
    setState(() {
      _players = n;
      _phase = _RhythmPhase.pickMode;
    });
  }

  void _pickMode(bool mic) {
    setState(() {
      _useMic = mic;
      _micFailed = false;
      _totals = List<int>.filled(_players, 0);
      _level = 1;
    });
    _startLevel();
  }

  void _startLevel() {
    _cancelTimers();
    setState(() {
      _pattern = _gen.next(_level);
      _turn = 0;
      _phase = _RhythmPhase.turnIntro;
    });
  }

  void _watch() {
    _cancelTimers();
    setState(() {
      _phase = _RhythmPhase.watching;
      _watchIndex = -1;
    });
    final onsets = _pattern.onsetsMs;
    for (var i = 0; i < onsets.length; i++) {
      _timers.add(Timer(Duration(milliseconds: onsets[i] + 600), () {
        if (!mounted || _phase != _RhythmPhase.watching) return;
        setState(() => _watchIndex = i);
        AudioService.playClick();
      }));
    }
    _timers.add(Timer(Duration(milliseconds: _pattern.totalMs + 1200), () {
      if (!mounted || _phase != _RhythmPhase.watching) return;
      _listen();
    }));
  }

  Future<void> _listen() async {
    _cancelTimers();
    _onsets.clear();
    _listenStart = _now();
    setState(() {
      _phase = _RhythmPhase.listening;
      _watchIndex = -1;
    });
    if (_useMic) {
      final detector =
          (widget.micDetectorFactory ?? MicClapDetector.new)();
      detector.onClap = _recordOnset;
      final ok = await detector.start();
      if (!mounted) return;
      if (!ok) {
        // Truthful fallback: mic unavailable or permission refused.
        setState(() {
          _micFailed = true;
          _useMic = false;
        });
      } else {
        _detector = detector;
      }
    }
    _listenTimer = Timer(Duration(milliseconds: _listenWindowMs), () {
      if (!mounted || _phase != _RhythmPhase.listening) return;
      _finishTurn();
    });
  }

  void _recordOnset() {
    if (!mounted || _phase != _RhythmPhase.listening) return;
    setState(() {
      _onsets.add(_now() - _listenStart);
      _listeningFlash = true;
    });
    Timer(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _listeningFlash = false);
    });
  }

  Future<void> _finishTurn() async {
    _listenTimer?.cancel();
    _listenTimer = null;
    await _detector?.stop();
    _detector = null;
    if (!mounted || _phase != _RhythmPhase.listening) return;
    final score = scoreAttempt(_pattern, _onsets);
    setState(() {
      _lastScore = score;
      _totals[_turn] += score.points;
      _phase = _RhythmPhase.turnResult;
    });
    if (score.passed) {
      AudioService.playSuccess();
    } else {
      AudioService.playFailure();
    }
  }

  void _nextTurn() {
    if (_turn + 1 < _players) {
      setState(() {
        _turn++;
        _phase = _RhythmPhase.turnIntro;
      });
    } else {
      setState(() => _phase = _RhythmPhase.levelResult);
    }
  }

  void _nextLevel() {
    if (_level >= widget.maxLevels) {
      setState(() => _phase = _RhythmPhase.over);
      AudioService.playWinVoice();
    } else {
      _level++;
      _startLevel();
    }
  }

  int? get _winner {
    if (_players == 1 || _totals.isEmpty) return null;
    var best = 0;
    for (var i = 1; i < _totals.length; i++) {
      if (_totals[i] > _totals[best]) best = i;
    }
    // Tie at the top: no winner.
    final top = _totals[best];
    if (_totals.where((t) => t == top).length > 1) return null;
    return best;
  }

  // -- UI -----------------------------------------------------------------

  TextStyle _t(double size,
          {FontWeight w = FontWeight.w800, Color color = FlatColors.ink}) =>
      flatCairo(fontSize: size, fontWeight: w, color: color)
          .copyWith(fontFamilyFallback: _emojiFallback);

  Widget _bigChoice(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        width: 240,
        child: FilledButton(
          onPressed: onTap,
          child: Text(label, style: _t(18).copyWith(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildPickPlayers() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('كام لاعب؟', style: _t(26)),
          const SizedBox(height: 20),
          _bigChoice('لاعب واحد', () => _pickPlayers(1)),
          for (final n in [2, 3, 4])
            _bigChoice('$n لاعبين', () => _pickPlayers(n)),
        ],
      ),
    );
  }

  Widget _buildPickMode() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('هتقلّدوا الإيقاع إزاي؟', style: _t(24)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'التصفيق بيستخدم المايك ولسه تحت التجربة على أجهزة حقيقية؛ لو المايك مش متاح هنحوّلك على الدوس تلقائي.',
              textAlign: TextAlign.center,
              style: _t(13, w: FontWeight.w600)
                  .copyWith(color: FlatColors.ink.withValues(alpha: 0.7)),
            ),
          ),
          const SizedBox(height: 20),
          _bigChoice('تصفيق 👏 (تجريبي)', () => _pickMode(true)),
          _bigChoice('دوس على الزرار 👆', () => _pickMode(false)),
        ],
      ),
    );
  }

  Widget _scorePills() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < _players; i++)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _colors[i].withValues(alpha: i == _turn ? 0.45 : 0.22),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _colors[i], width: 1.4),
              ),
              child: Text('${_totals[i]} :${i + 1}', style: _t(14)),
            ),
        ],
      ),
    );
  }

  Widget _patternDots() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < _pattern.claps; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: i == _watchIndex ? 34 : 26,
              height: i == _watchIndex ? 34 : 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == _watchIndex
                    ? _colors[_turn]
                    : _colors[_turn].withValues(alpha: 0.25),
                border: Border.all(color: FlatColors.ink, width: 2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTurnIntro() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('مستوى $_level', style: _t(16, w: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('دور ${PlayerNames.name(_turn)}',
              style: _t(30).copyWith(color: _colors[_turn])),
          const SizedBox(height: 8),
          Text(
            _useMic ? 'اسمع الإيقاع كويس.. وبعدين صفّق زيه 👏'
                : 'اسمع الإيقاع كويس.. وبعدين دوس زيه 👆',
            textAlign: TextAlign.center,
            style: _t(16, w: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          _bigChoice('يلا ▶', _watch),
        ],
      ),
    );
  }

  Widget _buildWatching() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('اسمع وشوف..', style: _t(22)),
          _patternDots(),
          Text('جاهز تقلّد؟', style: _t(14, w: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildListening() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_micFailed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'المايك مش متاح أو الإذن مرفوض — كمّل بالدوس على الزرار 👆',
                textAlign: TextAlign.center,
                style: _t(14, w: FontWeight.w700)
                    .copyWith(color: FunkyColors.coral),
              ),
            ),
          Text('دورك! قلّد الإيقاع دلوقتي',
              style: _t(22).copyWith(color: _colors[_turn])),
          const SizedBox(height: 8),
          Text('${_onsets.length} من ${_pattern.claps}', style: _t(15)),
          const SizedBox(height: 18),
          if (_useMic)
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _listeningFlash
                    ? _colors[_turn]
                    : _colors[_turn].withValues(alpha: 0.25),
                border: Border.all(color: FlatColors.ink, width: 3),
              ),
              child: const Center(
                child: Text('👏', style: TextStyle(fontSize: 46)),
              ),
            )
          else
            GestureDetector(
              key: const Key('rhythm_tap_pad'),
              onTap: _recordOnset,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _listeningFlash
                      ? Colors.white
                      : _colors[_turn],
                  border: Border.all(color: FlatColors.ink, width: 3),
                ),
                child: Center(
                  child: Text('دوس\n👆',
                      textAlign: TextAlign.center,
                      style: _t(20).copyWith(
                          color: _listeningFlash
                              ? _colors[_turn]
                              : Colors.white)),
                ),
              ),
            ),
          const SizedBox(height: 18),
          _patternDots(),
        ],
      ),
    );
  }

  Widget _buildTurnResult() {
    final s = _lastScore!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            s.passed ? 'جامد! ${s.accuracy}%' : 'لسه.. ${s.accuracy}%',
            style: _t(28).copyWith(
                color: s.passed ? FlatColors.ink : FunkyColors.coral),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < s.errorsMs.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    s.errorsMs[i] == null
                        ? Icons.close
                        : s.errorsMs[i]! <= RhythmScoring.perfectMs
                            ? Icons.star
                            : Icons.star_half,
                    color: s.errorsMs[i] == null
                        ? FunkyColors.coral
                        : const Color(0xFFE0A800),
                    size: 26,
                  ),
                ),
            ],
          ),
          if (_useMic)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('نقاط وضع المايك تجريبية لحد ما تتأكد دقته على جهاز',
                  style: _t(11, w: FontWeight.w600)
                      .copyWith(color: FlatColors.ink.withValues(alpha: 0.6))),
            ),
          const SizedBox(height: 22),
          _bigChoice('تمام', _nextTurn),
        ],
      ),
    );
  }

  Widget _buildLevelResult() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('خلص مستوى $_level', style: _t(26)),
          const SizedBox(height: 14),
          for (var i = 0; i < _players; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text('${PlayerNames.name(i)}: ${_totals[i]} نقطة',
                  style: _t(18).copyWith(color: _colors[i])),
            ),
          const SizedBox(height: 20),
          _bigChoice(
              _level >= widget.maxLevels ? 'النتيجة النهائية 🏁' : 'المستوى اللي بعده ⬆',
              _nextLevel),
        ],
      ),
    );
  }

  Widget _buildOver() {
    final w = _winner;
    final practice = _players == 1;
    Widget head;
    if (practice) {
      head = Text('انتهى التدريب 👏\nجمعت ${_totals[0]} نقطة',
          textAlign: TextAlign.center, style: _t(20));
    } else if (w == null) {
      head = Text('تعادل! 🤝', style: _t(24));
    } else {
      head = VictoryFriends(
        gameTitle: 'تحدّي الإيقاع',
        winnerName: '${PlayerNames.name(w)}',
        winnerSeats: [w],
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          head,
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () =>
                setState(() => _phase = _RhythmPhase.pickPlayers),
            child:
                Text('العبوا تاني 👏', style: _t(18).copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: 'تحدّي الإيقاع',
        backgroundColor: FlatColors.bg,
        body: GameIntroWidget(
        title: 'تحدّي الإيقاع',
            playersLabel: '١-٤ لاعبين',
            showBotsChip: true,
        description:
            'من ١ ل٤ لاعبين، واحد واحد بيلف عليهم الدور. الموبايل يشغّل إيقاع تصفيق قصير، واللي عليه الدور يقلّده: يا تصفيق قدام المايك 👏 (وضع تجريبي) يا دوس على الزرار 👆. كل مستوى الإيقاع بيطول ويصعب، وأدق توقيت يكسب!',
        icon: '👏',
        onStart: () => setState(() => _showIntro = false),
      ),
      );
    }
    final inMatch = _phase != _RhythmPhase.pickPlayers &&
        _phase != _RhythmPhase.pickMode;
    return OfflineGameScaffold(
      title: 'تحدّي الإيقاع',
      backgroundColor: FlatColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            if (inMatch) _scorePills(),
            Expanded(
              child: switch (_phase) {
                _RhythmPhase.pickPlayers => _buildPickPlayers(),
                _RhythmPhase.pickMode => _buildPickMode(),
                _RhythmPhase.turnIntro => _buildTurnIntro(),
                _RhythmPhase.watching => _buildWatching(),
                _RhythmPhase.listening => _buildListening(),
                _RhythmPhase.turnResult => _buildTurnResult(),
                _RhythmPhase.levelResult => _buildLevelResult(),
                _RhythmPhase.over => _buildOver(),
              },
            ),
          ],
        ),
      ),
    );
  }
}
