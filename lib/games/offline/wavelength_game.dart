import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../screens/global_player_selection_screen.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/game_intro_widget.dart';
import '../../services/audio_service.dart';
import '../../data/wavelength_data.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';

/// المؤشر — exact clone of Wavelength, adapted for one phone:
/// - 2 teams, rotating Psychic. The Psychic secretly sees the hidden
///   target on a spectrum between two opposing concepts and gives ONE clue
///   that sits conceptually where the target is.
/// - Their team discusses and drags the dial. No percentages (house note
///   shown in the intro, as the rulebook asks).
/// - The other team guesses whether the target center is LEFT or RIGHT of
///   the dial — they score 1 point if right, even on someone else's turn.
/// - Dial inside the target wedges scores 2/3/4 points (edge = the better
///   result). First to 10 wins; the second team starts with 1 point.
/// - Catch-up rule: a team that scores 4 while still losing plays again
///   immediately (new Psychic). Ties at 10+ go to sudden-death rounds.
class WavelengthGame extends StatefulWidget {
  const WavelengthGame({super.key});

  /// Points for a dial position given the target center. Wedge widths in
  /// spectrum percent: 4-pt ±3, 3-pt ±7, 2-pt ±11.
  static int scoreDial(double dial, double target) {
    final dist = (dial - target).abs();
    if (dist <= 3) return 4;
    if (dist <= 7) return 3;
    if (dist <= 11) return 2;
    return 0;
  }

  @override
  State<WavelengthGame> createState() => _WavelengthGameState();
}

enum _WPhase { psychicPass, psychic, team, leftright, reveal, gameOver }

class _WavelengthGameState extends State<WavelengthGame> {
  final math.Random _rng = math.Random(41);
  final TextEditingController _clueController = TextEditingController();

  bool _showIntro = true;
  bool _started = false;

  List<String> _teamA = [];
  List<String> _teamB = [];
  int _scoreA = 0;
  int _scoreB = 1; // official: the second team starts with 1 point
  bool _teamATurn = true;
  final List<int> _psychicIdx = [0, 0];

  _WPhase _phase = _WPhase.psychicPass;
  Map<String, String> _pair = wavelengthPairs[0];
  double _target = 50;
  double _dial = 50;
  String _clue = '';
  bool? _lrGuessLeft; // other team's guess: true = left
  int _lastDialPts = 0;
  bool _lastLrPoint = false;
  bool _catchUp = false;
  String? _entryError;

  List<String> get _activeTeam => _teamATurn ? _teamA : _teamB;
  List<String> get _otherTeam => _teamATurn ? _teamB : _teamA;
  String get _psychic =>
      _activeTeam[_psychicIdx[_teamATurn ? 0 : 1] % _activeTeam.length];

  void _start(List<String> names) {
    final shuffled = List.of(names)..shuffle(_rng);
    setState(() {
      _teamA = [for (var i = 0; i < shuffled.length; i += 2) shuffled[i]];
      _teamB = [for (var i = 1; i < shuffled.length; i += 2) shuffled[i]];
      _scoreA = 0;
      _scoreB = 1;
      _teamATurn = true;
      _psychicIdx[0] = 0;
      _psychicIdx[1] = 0;
      _started = true;
      _newRound();
    });
  }

  void _newRound() {
    _pair = wavelengthPairs[_rng.nextInt(wavelengthPairs.length)];
    // Keep the 4-pt wedge fully on the dial, like the physical wheel.
    _target = 12 + _rng.nextDouble() * 76;
    _dial = 50;
    _clue = '';
    _lrGuessLeft = null;
    _catchUp = false;
    _entryError = null;
    _clueController.clear();
    _phase = _WPhase.psychicPass;
  }

  void _submitClue() {
    final clue = _clueController.text.trim();
    if (clue.isEmpty) {
      setState(() => _entryError = 'اكتب التلميح الأول! ✍️');
      return;
    }
    if (clue.contains(_pair['left']!) || clue.contains(_pair['right']!)) {
      setState(() => _entryError = 'التلميح ميفهش فيه كلمات الكارت نفسها! 🚫');
      return;
    }
    AudioService.playClick();
    setState(() {
      _clue = clue;
      _entryError = null;
      _phase = _WPhase.team;
    });
  }

  void _lockDial() {
    AudioService.playClick();
    setState(() => _phase = _WPhase.leftright);
  }

  void _pickLeftRight(bool left) {
    AudioService.playClick();
    setState(() {
      _lrGuessLeft = left;
      _reveal();
    });
  }

  void _reveal() {
    final pts = WavelengthGame.scoreDial(_dial, _target);
    final targetLeftOfDial = _target < _dial;
    final lrPoint = _lrGuessLeft == targetLeftOfDial && pts < 4;
    setState(() {
      _lastDialPts = pts;
      _lastLrPoint = lrPoint;
      if (_teamATurn) {
        _scoreA += pts;
        if (lrPoint) _scoreB += 1;
      } else {
        _scoreB += pts;
        if (lrPoint) _scoreA += 1;
      }
      // Catch-up rule (official): 4 points while still losing = go again.
      final activeScore = _teamATurn ? _scoreA : _scoreB;
      final otherScore = _teamATurn ? _scoreB : _scoreA;
      _catchUp = pts == 4 && activeScore < otherScore;
      _phase = _WPhase.reveal;
      if (pts > 0) {
        AudioService.playSuccess();
      } else {
        AudioService.playFailure();
      }
    });
  }

  bool get _someoneWon => _scoreA >= 10 || _scoreB >= 10;

  void _nextRound() {
    AudioService.playClick();
    setState(() {
      if (_someoneWon && _scoreA != _scoreB) {
        _phase = _WPhase.gameOver;
        AudioService.playWinVoice();
        return;
      }
      // Tie at 10+ = sudden death rounds until they differ.
      if (!_catchUp) {
        _teamATurn = !_teamATurn;
        _psychicIdx[_teamATurn ? 0 : 1]++;
      } else {
        _psychicIdx[_teamATurn ? 0 : 1]++;
      }
      _newRound();
    });
  }

  @override
  void dispose() {
    _clueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: '📡 المؤشر',
        backgroundColor: FunkyColors.cyan,
        body: GameIntroWidget(
          title: '📡 المؤشر',
          icon: '📡',
          description:
              'فريقين بيقروا أفكار بعض!\n\n🔮 الواصي (الوسيط) بيشوف هدف مخفي على مؤشر بين حاجتين متضادتين (حار / ساقع) ويقول تلميح واحد بس.\n🎯 فريقه يتناقش ويحرك المؤشر لأقرب نقطة للهدف.\n↔️ الفريق التاني يخمن الهدف شمال ولا يمين المؤشر — ولو صح ياخد نقطة!\n\n⭐ قلب الهدف = 4 نقاط. أول فريق يوصل 10 يكسب. وممنوع النسب والأرقام في النقاش!',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }

    if (!_started) {
      return GlobalPlayerSelectionScreen(
        gameTitle: '📡 المؤشر',
        minPlayers: 4,
        maxPlayers: 10,
        onStartGame: (ctx, selected) => _start(selected),
      );
    }

    switch (_phase) {
      case _WPhase.psychicPass:
        return _buildPsychicPass();
      case _WPhase.psychic:
        return _buildPsychic();
      case _WPhase.team:
        return _buildTeam();
      case _WPhase.leftright:
        return _buildLeftRight();
      case _WPhase.reveal:
        return _buildReveal();
      case _WPhase.gameOver:
        return _buildGameOver();
    }
  }

  Widget _scoreHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _teamScoreChip('الفريق الأول', _scoreA, _teamATurn),
          _teamScoreChip('الفريق التاني', _scoreB, !_teamATurn),
        ],
      ),
    );
  }

  Widget _teamScoreChip(String label, int score, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: active ? FlatColors.mintDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FlatColors.ink, width: 2),
      ),
      child: Text(
        '$label: $score',
        style: flatCairo(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: active ? Colors.white : FlatColors.ink,
        ),
        textDirection: TextDirection.rtl,
      ),
    );
  }

  /// The semicircular spectrum dial. Shows the hidden target wedges only
  /// when [showTarget] is true (psychic view and reveal).
  Widget _dialWidget({required bool showTarget, required bool interactive}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = w * 0.56;
        return GestureDetector(
          onPanUpdate: interactive
              ? (d) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  final local = box.globalToLocal(d.globalPosition);
                  final cx = w / 2;
                  final cy = h - 8;
                  final dx = local.dx - cx;
                  final dy = cy - local.dy;
                  var ang = math.atan2(dy, dx); // pi..0 left->right
                  ang = ang.clamp(0.0, math.pi);
                  setState(() => _dial = (1 - ang / math.pi) * 100);
                }
              : null,
          child: CustomPaint(
            size: Size(w, h),
            painter: _DialPainter(
              dial: _dial,
              target: _target,
              showTarget: showTarget,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPsychicPass() {
    final teamName = _teamATurn ? 'الأول' : 'التاني';
    return OfflineGameScaffold(
      title: '📡 المؤشر',
      backgroundColor: FunkyColors.cyan,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _scoreHeader(),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: FlatColors.ink, width: 3),
                ),
                child: Column(
                  children: [
                    const Text('🔮', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 12),
                    Text(
                      'عدّي الموبايل لـ $_psychic',
                      textAlign: TextAlign.center,
                      style: flatCairo(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: FlatColors.ink,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'واصي الفريق $teamName.. هو بس اللي يشوف الهدف',
                      textAlign: TextAlign.center,
                      style: flatCairo(
                        fontSize: 16,
                        color: FlatColors.ink.withValues(alpha: 0.75),
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  AudioService.playClick();
                  setState(() => _phase = _WPhase.psychic);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlatColors.mintDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 36,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'تمام، أنا $_psychic',
                  style: flatCairo(fontSize: 20, fontWeight: FontWeight.w900),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPsychic() {
    return OfflineGameScaffold(
      title: '📡 المؤشر',
      backgroundColor: FunkyColors.cyan,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _scoreHeader(),
              Text(
                '$_psychic، الهدف قدامك بس.. محدش يبص! 🤫',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 8),
              _spectrumLabels(),
              _dialWidget(showTarget: true, interactive: false),
              const SizedBox(height: 12),
              Text(
                'قول تلميح مكانه على المؤشر:',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: FlatColors.ink.withValues(alpha: 0.75),
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _clueController,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: flatCairo(fontSize: 20, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: 'مثال: قهوة الصبح...',
                  hintStyle: flatCairo(
                    fontSize: 16,
                    color: FlatColors.ink.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(
                      color: FlatColors.ink,
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(
                      color: FlatColors.ink,
                      width: 2,
                    ),
                  ),
                ),
                onSubmitted: (_) => _submitClue(),
              ),
              if (_entryError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _entryError!,
                  textAlign: TextAlign.center,
                  style: flatCairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: FlatColors.mafia,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _submitClue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlatColors.mintDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'قولتها! اخفي الهدف 🙈',
                  style: flatCairo(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _spectrumLabels() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _pair['left']!,
            style: flatCairo(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: FlatColors.mafia,
            ),
            textDirection: TextDirection.rtl,
          ),
          Text(
            _pair['right']!,
            style: flatCairo(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: FlatColors.detective,
            ),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  Widget _buildTeam() {
    final teamName = _teamATurn ? 'الأول' : 'التاني';
    return OfflineGameScaffold(
      title: '📡 المؤشر',
      backgroundColor: FunkyColors.cyan,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _scoreHeader(),
              Text(
                'فريق $teamName، حركوا المؤشر! 🎯',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: FlatColors.ink, width: 2),
                ),
                child: Text(
                  'التلميح: $_clue',
                  textAlign: TextAlign.center,
                  style: flatCairo(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: FlatColors.mintDark,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
              const SizedBox(height: 10),
              _spectrumLabels(),
              _dialWidget(showTarget: false, interactive: true),
              const Spacer(),
              ElevatedButton(
                onPressed: _lockDial,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlatColors.mintDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'ثبّتوا المؤشر 🔒',
                  style: flatCairo(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeftRight() {
    final teamName = _teamATurn ? 'التاني' : 'الأول';
    return OfflineGameScaffold(
      title: '📡 المؤشر',
      backgroundColor: FunkyColors.cyan,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _scoreHeader(),
              Text(
                'فريق $teamName: الهدف شمال ولا يمين؟ ↔️',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 6),
              Text(
                'لو صحبتكم صح، تاخدوا نقطة من دور غيركم!',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 14,
                  color: FlatColors.ink.withValues(alpha: 0.7),
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 10),
              _spectrumLabels(),
              _dialWidget(showTarget: false, interactive: false),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pickLeftRight(false),
                      icon: const Icon(Icons.arrow_forward, size: 28),
                      label: Text(
                        'يمين',
                        style: flatCairo(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlatColors.detective,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pickLeftRight(true),
                      icon: const Icon(Icons.arrow_back, size: 28),
                      label: Text(
                        'شمال',
                        style: flatCairo(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlatColors.mafia,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReveal() {
    final teamName = _teamATurn ? 'الأول' : 'التاني';
    final otherName = _teamATurn ? 'التاني' : 'الأول';
    final (emoji, headline) = switch (_lastDialPts) {
      4 => ('🎯', 'في القلب! 4 نقاط'),
      3 => ('🔥', 'قريب جدًا! 3 نقاط'),
      2 => ('👍', 'داخل الهدف! نقطتين'),
      _ => ('💨', 'بره الهدف خالص!'),
    };
    return OfflineGameScaffold(
      title: '📡 المؤشر',
      backgroundColor: FunkyColors.cyan,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _scoreHeader(),
              Text(
                '$emoji  $headline',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 4),
              if (_lastLrPoint)
                Text(
                  'وفريق $otherName خطف نقطة بالـ${(_lrGuessLeft ?? false) ? "شمال" : "يمين"} الصح! ⚡',
                  textAlign: TextAlign.center,
                  style: flatCairo(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: FlatColors.detective,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              if (_catchUp)
                Text(
                  'قاعدة اللحاق! فريق $teamName لسه متأخر.. يلعبوا تاني فورًا 🔁',
                  textAlign: TextAlign.center,
                  style: flatCairo(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: FlatColors.mafia,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              const SizedBox(height: 8),
              _spectrumLabels(),
              _dialWidget(showTarget: true, interactive: false),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _nextRound,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlatColors.mintDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _someoneWon && _scoreA != _scoreB
                      ? 'النتيجة النهائية 🏆'
                      : (_catchUp ? 'دور اللحاق 🔁' : 'الدور الجاي ⏭️'),
                  style: flatCairo(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameOver() {
    final aWon = _scoreA > _scoreB;
    final winners = aWon ? _teamA : _teamB;
    final winName = aWon ? 'الأول' : 'التاني';
    return OfflineGameScaffold(
      title: '📡 المؤشر',
      backgroundColor: FunkyColors.cyan,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                '🏆',
                style: TextStyle(fontSize: 72),
              ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
              Text(
                'الفريق $winName كسب!',
                style: flatCairo(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              Text(
                '$_scoreA - $_scoreB',
                style: flatCairo(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: FlatColors.mintDark,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: FlatColors.ink, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الأبطال:',
                        style: flatCairo(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: FlatColors.ink,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView(
                          children: winners
                              .map(
                                (p) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  child: Text(
                                    '⭐ $p',
                                    style: flatCairo(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: FlatColors.ink,
                                    ),
                                    textDirection: TextDirection.rtl,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  AudioService.playClick();
                  setState(() {
                    _started = false;
                    _teamA = [];
                    _teamB = [];
                  });
                },
                icon: const Icon(Icons.replay),
                label: Text(
                  'العبوا تاني!',
                  style: flatCairo(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlatColors.mintDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  final double dial; // 0..100 (left..right)
  final double target; // 0..100
  final bool showTarget;

  _DialPainter({
    required this.dial,
    required this.target,
    required this.showTarget,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height - 8;
    final radius = size.width / 2 - 12;

    final basePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      math.pi,
      math.pi,
      true,
      basePaint,
    );

    if (showTarget) {
      void wedge(double centerPct, double halfWidth, Color color) {
        final startPct = (centerPct - halfWidth).clamp(0.0, 100.0);
        final endPct = (centerPct + halfWidth).clamp(0.0, 100.0);
        // y-down canvas: the upper semicircle runs clockwise from angle pi
        // (left) through 3pi/2 (top) to 2pi (right).
        final startAng = math.pi + (startPct / 100) * math.pi;
        final sweep = ((endPct - startPct) / 100) * math.pi;
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: radius - 14),
          startAng,
          sweep,
          true,
          Paint()..color = color,
        );
      }

      wedge(target, 11, FlatColors.day.withValues(alpha: 0.5));
      wedge(target, 7, FlatColors.doctor.withValues(alpha: 0.65));
      wedge(target, 3, FlatColors.mintDark);
    }

    // Outline
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      math.pi,
      math.pi,
      true,
      Paint()
        ..color = FlatColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Needle
    final ang = math.pi - (dial / 100) * math.pi;
    final tip = Offset(
      cx + (radius - 6) * math.cos(ang),
      cy - (radius - 6) * math.sin(ang),
    );
    canvas.drawLine(
      Offset(cx, cy),
      tip,
      Paint()
        ..color = FlatColors.mafia
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(cx, cy), 10, Paint()..color = FlatColors.ink);
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.dial != dial || old.target != target || old.showTarget != showTarget;
}
