import 'dart:math';

import 'package:flutter/material.dart';
import '../../screens/global_player_selection_screen.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/game_intro_widget.dart';
import '../../services/audio_service.dart';
import '../../data/fake_artist_data.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';

/// الرسام المزيف — exact clone of "A Fake Artist Goes to New York"
/// (Oink Games): a Question Master picks a title in an announced
/// category; every artist gets the title except ONE who gets the X and
/// draws blind. Each artist adds ONE continuous line per turn to the
/// shared masterpiece, twice around the table. Then everyone points at a
/// suspect: if the fake gets the most votes he is caught but can still
/// win by naming the title (one guess). Scoring (official): fake
/// escapes or guesses right = fake 2 pts + QM 2 pts; fake caught and
/// wrong = every real artist 1 pt. First player to 5 points wins; the QM
/// rotates to the left every round.
class FakeArtistGame extends StatefulWidget {
  const FakeArtistGame({super.key});

  static const int winPoints = 5;

  @override
  State<FakeArtistGame> createState() => _FakeArtistGameState();
}

enum _FPhase {
  intro,
  players,
  qmPick,
  dealPass,
  dealShow,
  draw,
  votePass,
  votePick,
  reveal,
  fakeGuess,
  roundScore,
  finalResults,
}

class _Stroke {
  _Stroke(this.color);
  final Color color;
  final List<Offset> points = [];
}

class _FakeArtistGameState extends State<FakeArtistGame> {
  _FPhase _phase = _FPhase.intro;
  final Random _rng = Random();

  List<String> _players = [];
  final Map<int, int> _scores = {};
  int _qmIndex = 0;
  int _fakeIndex = 1;

  Map<String, dynamic> _category = fakeArtistCategories.first;
  List<String> _options = [];
  String _title = '';

  int _dealIndex = 0;
  bool _dealRevealed = false;

  // Drawing
  List<int> _artists = []; // player indices in drawing order
  int _drawTurn = 0; // index into _artists
  int _drawRound = 1; // 1 or 2
  final List<_Stroke> _strokes = [];
  _Stroke? _currentStroke;
  bool _strokeDone = false;

  // Voting
  final Map<int, int> _votes = {}; // voted player -> count
  int _voteIndex = 0; // artist index into _artists
  int? _pickedVote;
  bool _fakeCaught = false;

  static const List<Color> _penColors = [
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
    Color(0xFF6D4C41),
    Color(0xFFD81B60),
  ];

  // ---------------------------------------------------------------- flow

  void _start(List<String> names) {
    _players = List<String>.from(names);
    _scores
      ..clear()
      ..addAll({for (var i = 0; i < _players.length; i++) i: 0});
    _qmIndex = 0;
    _setupRound();
  }

  void _setupRound() {
    // Fake is a random artist (never the QM).
    final artistIdxs = [
      for (var i = 0; i < _players.length; i++)
        if (i != _qmIndex) i,
    ];
    _fakeIndex = artistIdxs[_rng.nextInt(artistIdxs.length)];
    _category = fakeArtistCategories[_rng.nextInt(fakeArtistCategories.length)];
    final titles = (_category['titles'] as List).cast<String>().toList()
      ..shuffle(_rng);
    _options = titles.take(3).toList();
    _title = '';
    _dealIndex = 0;
    _dealRevealed = false;
    // Drawing order starts at the player left of the QM (official).
    _artists = [
      for (var k = 1; k < _players.length; k++)
        (_qmIndex + k) % _players.length,
    ];
    _drawTurn = 0;
    _drawRound = 1;
    _strokes.clear();
    _currentStroke = null;
    _strokeDone = false;
    _votes.clear();
    _voteIndex = 0;
    _pickedVote = null;
    _fakeCaught = false;
    setState(() => _phase = _FPhase.qmPick);
  }

  void _onPanStart(DragStartDetails d) {
    if (_strokeDone) return;
    final artist = _artists[_drawTurn];
    _currentStroke = _Stroke(_penColors[artist % _penColors.length]);
    _currentStroke!.points.add(d.localPosition);
    setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_strokeDone || _currentStroke == null) return;
    _currentStroke!.points.add(d.localPosition);
    setState(() {});
  }

  void _onPanEnd(DragEndDetails d) {
    if (_currentStroke == null) return;
    if (_currentStroke!.points.length < 2) {
      // A dot is not a line.
      _currentStroke = null;
      return;
    }
    _strokes.add(_currentStroke!);
    _currentStroke = null;
    _strokeDone = true;
    AudioService.playClick();
    setState(() {});
  }

  void _nextStroke() {
    _strokeDone = false;
    if (_drawTurn < _artists.length - 1) {
      _drawTurn++;
    } else {
      _drawTurn = 0;
      _drawRound = 2;
      if (_strokes.length >= _artists.length * 2) {
        // Two full rounds done -> vote.
        _voteIndex = 0;
        _pickedVote = null;
        setState(() => _phase = _FPhase.votePass);
        return;
      }
    }
    setState(() {});
  }

  int get _strokesExpected => _artists.length * 2;

  void _castVote(int suspect) {
    _votes[suspect] = (_votes[suspect] ?? 0) + 1;
    AudioService.playClick();
    if (_voteIndex < _artists.length - 1) {
      _voteIndex++;
      _pickedVote = null;
      setState(() => _phase = _FPhase.votePass);
    } else {
      _tallyVotes();
    }
  }

  void _tallyVotes() {
    var maxVotes = 0;
    var leaders = 0;
    int? leaderIdx;
    for (final e in _votes.entries) {
      if (e.value > maxVotes) {
        maxVotes = e.value;
        leaders = 1;
        leaderIdx = e.key;
      } else if (e.value == maxVotes) {
        leaders++;
      }
    }
    // Caught only when the fake is the single most-voted player.
    _fakeCaught = leaders == 1 && leaderIdx == _fakeIndex;
    AudioService.playFailure();
    setState(() => _phase = _FPhase.reveal);
  }

  void _applyScore({required bool fakeGuessedRight}) {
    if (!_fakeCaught || fakeGuessedRight) {
      // Fake escapes OR caught but names the title: fake 2, QM 2.
      _scores[_fakeIndex] = (_scores[_fakeIndex] ?? 0) + 2;
      _scores[_qmIndex] = (_scores[_qmIndex] ?? 0) + 2;
    } else {
      // Caught and wrong: every real artist 1 point.
      for (final a in _artists) {
        if (a != _fakeIndex) _scores[a] = (_scores[a] ?? 0) + 1;
      }
    }
    final winner = _scores.entries.any(
      (e) => e.value >= FakeArtistGame.winPoints,
    );
    AudioService.playWinVoice();
    setState(() => _phase = winner ? _FPhase.finalResults : _FPhase.roundScore);
  }

  void _nextRound() {
    // The player to the left of the QM becomes the next QM (official).
    _qmIndex = (_qmIndex + 1) % _players.length;
    _setupRound();
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _FPhase.intro:
        return OfflineGameScaffold(
          title: '🎨 الرسام المزيف',
          backgroundColor: FunkyColors.pink,
          body: GameIntroWidget(
            title: 'الرسام المزيف 🎨',
            icon: '🎨',
            description:
                'اللعبة الأصلية A Fake Artist Goes to New York!\n\n'
                '🕵️ واحد فيكم رسام مزيف.. مش عارف بيرسموا إيه!\n'
                '🎨 كل واحد يرسم خط واحد بس في دوره، مرتين بالمرة.\n'
                '👆 بعدها الكل يصوّت: مين المزيف؟\n'
                '😈 لو المزيف هرب أو خمّن الرسمة صح.. ياخد هو والمعلّم نقطتين!\n\n'
                'أول واحد يوصل 5 نقط يكسب!',
            onStart: () {
              AudioService.playClick();
              setState(() => _phase = _FPhase.players);
            },
          ),
        );
      case _FPhase.players:
        return GlobalPlayerSelectionScreen(
          gameTitle: '🎨 الرسام المزيف',
          minPlayers: 4,
          maxPlayers: 8,
          onStartGame: (ctx, selected) => _start(selected),
        );
      case _FPhase.qmPick:
        return _buildQmPick();
      case _FPhase.dealPass:
        return _buildDealPass();
      case _FPhase.dealShow:
        return _buildDealShow();
      case _FPhase.draw:
        return _buildDraw();
      case _FPhase.votePass:
        return _buildVotePass();
      case _FPhase.votePick:
        return _buildVotePick();
      case _FPhase.reveal:
        return _buildReveal();
      case _FPhase.fakeGuess:
        return _buildFakeGuess();
      case _FPhase.roundScore:
        return _buildRoundScore();
      case _FPhase.finalResults:
        return _buildFinal();
    }
  }

  Widget _scaffold(Widget body) => OfflineGameScaffold(
    title: '🎨 الرسام المزيف',
    backgroundColor: FunkyColors.pink,
    body: body,
  );

  Widget _buildQmPick() {
    return _scaffold(
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              'سلّم الموبايل للمعلّم 🎩',
              style: flatCairo(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: FlatColors.ink,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: FlatColors.ink, width: 2.5),
              ),
              child: Column(
                children: [
                  Text(
                    'المعلّم الجولة دي: ${_players[_qmIndex]}',
                    style: flatCairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: FlatColors.mintDark,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'الفئة: ${_category['icon']} ${_category['name']}\n(قولها بصوت عالي للكل!)',
                    textAlign: TextAlign.center,
                    style: flatCairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: FlatColors.ink,
                      height: 1.6,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'اختار عنوان في سرية يا معلّم:',
              style: flatCairo(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: FlatColors.ink,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 10),
            ..._options.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _bigButton(
                  t,
                  () {
                    _title = t;
                    AudioService.playClick();
                    setState(() => _phase = _FPhase.dealPass);
                  },
                  color: Colors.white,
                  textColor: FlatColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _dealPlayer() {
    // Deal only to artists (QM already knows the title).
    return _artists[_dealIndex];
  }

  Widget _buildDealPass() {
    return _scaffold(
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'عدّي الموبايل لـ\n${_players[_dealPlayer()]} 📲',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                  height: 1.6,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 10),
              Text(
                'من غير ما حد يبص!',
                style: flatCairo(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 24),
              _bigButton('تمام، أنا ${_players[_dealPlayer()]} 👀', () {
                AudioService.playClick();
                _dealRevealed = false;
                setState(() => _phase = _FPhase.dealShow);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDealShow() {
    final p = _dealPlayer();
    final isFake = p == _fakeIndex;
    return _scaffold(
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_dealRevealed) ...[
                Text(
                  'يا ${_players[p]}..\nدوس تشوف كارتك في سرية 🤫',
                  textAlign: TextAlign.center,
                  style: flatCairo(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: FlatColors.ink,
                    height: 1.6,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 24),
                _bigButton('شوف الكارت 🃏', () {
                  AudioService.playClick();
                  _dealRevealed = true;
                  setState(() {});
                }),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isFake ? FlatColors.mafia : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: FlatColors.ink, width: 2.5),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isFake ? '❌' : _title,
                        textAlign: TextAlign.center,
                        style: flatCairo(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: isFake ? Colors.white : FlatColors.ink,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isFake
                            ? 'أنت الرسام المزيف! 😈\nارسم وياك تبان.. ومتحاولش تعرف العنوان'
                            : 'ارسمه بخط واحد كل دور..\nمن غير ما توضّحه قوي!',
                        textAlign: TextAlign.center,
                        style: flatCairo(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isFake ? Colors.white : FlatColors.ink,
                          height: 1.6,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _bigButton(
                  _dealIndex < _artists.length - 1
                      ? 'فهمت، عدّيها ⏭️'
                      : 'يلا نرسم! 🎨',
                  () {
                    AudioService.playClick();
                    if (_dealIndex < _artists.length - 1) {
                      _dealIndex++;
                      setState(() => _phase = _FPhase.dealPass);
                    } else {
                      setState(() => _phase = _FPhase.draw);
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDraw() {
    final artist = _artists[_drawTurn];
    return _scaffold(
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'الفئة: ${_category['icon']} ${_category['name']}  •  دور ${_drawRound} من 2',
              style: flatCairo(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: FlatColors.ink,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: _penColors[artist % _penColors.length],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: FlatColors.ink, width: 2),
              ),
              child: Text(
                '${_players[artist]}: ارسم خط واحد بس! ✏️',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: LayoutBuilder(
                builder: (ctx, cons) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: FlatColors.ink, width: 2.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: GestureDetector(
                        key: const Key('fakeArtistCanvas'),
                        onPanStart: _onPanStart,
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: CustomPaint(
                          painter: _MasterpiecePainter(
                            strokes: _strokes,
                            current: _currentStroke,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'خطوط متبقية: ${_strokesExpected - _strokes.length}',
              style: flatCairo(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: FlatColors.ink,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 8),
            _bigButton(
              _strokeDone ? 'تمام، سلّم اللي بعده ⏭️' : 'ارسم خطك الأول ✏️',
              _strokeDone
                  ? _nextStroke
                  : () {
                      AudioService.playFailure();
                    },
              color: _strokeDone ? FlatColors.mintDark : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVotePass() {
    final voter = _artists[_voteIndex];
    return _scaffold(
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '🕵️ وقت التصويت!\nعدّي الموبايل لـ ${_players[voter]}',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                  height: 1.6,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 24),
              _bigButton('تمام، أنا ${_players[voter]} 🤫', () {
                AudioService.playClick();
                setState(() => _phase = _FPhase.votePick);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVotePick() {
    final voter = _artists[_voteIndex];
    final suspects = [
      for (final a in _artists)
        if (a != voter) a,
    ];
    return _scaffold(
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              'يا ${_players[voter]}..\nمين الرسام المزيف؟ 🕵️',
              textAlign: TextAlign.center,
              style: flatCairo(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: FlatColors.ink,
                height: 1.6,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: FlatColors.ink, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CustomPaint(
                    painter: _MasterpiecePainter(strokes: _strokes),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: suspects
                    .map(
                      (sIdx) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _bigButton(
                          _players[sIdx],
                          () => _castVote(sIdx),
                          color: Colors.white,
                          textColor: FlatColors.ink,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReveal() {
    final sorted = _votes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _scaffold(
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _fakeCaught
                    ? '🚨 اتمسك! ${_players[_fakeIndex]} هو الرسام المزيف!'
                    : '😈 المزيف هرب! محدش مسكه..',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                  height: 1.6,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: FlatColors.ink, width: 2),
                ),
                child: Column(
                  children: [
                    for (final e in sorted)
                      Text(
                        '${_players[e.key]}: ${e.value} صوت',
                        style: flatCairo(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: e.key == _fakeIndex
                              ? FlatColors.mafia
                              : FlatColors.ink,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _bigButton(
                _fakeCaught
                    ? 'آخر فرصة للمزيف.. يخمّن العنوان! 😈'
                    : 'شوف النقط 📊',
                () {
                  AudioService.playClick();
                  if (_fakeCaught) {
                    setState(() => _phase = _FPhase.fakeGuess);
                  } else {
                    _applyScore(fakeGuessedRight: false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFakeGuess() {
    return _scaffold(
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 180,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: FlatColors.ink, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CustomPaint(
                      painter: _MasterpiecePainter(strokes: _strokes),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'يا ${_players[_fakeIndex]}..\nالفئة كانت "${_category['name']}".\nإيه العنوان؟ عندك تخمينة واحدة بس! 🎤',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                  height: 1.7,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 8),
              Text(
                '(قولها بصوت عالي.. والجروب يحكم)',
                style: flatCairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _bigButton(
                      'غلط ❌',
                      () => _applyScore(fakeGuessedRight: false),
                      color: FlatColors.mafia,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _bigButton(
                      'خمّنها صح! ✅',
                      () => _applyScore(fakeGuessedRight: true),
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

  Widget _buildRoundScore() {
    return _scaffold(
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'العنوان كان: $_title 🖼️',
                style: flatCairo(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 14),
              _scoreBoard(),
              const SizedBox(height: 24),
              _bigButton('الجولة اللي بعدها 🔄', () {
                AudioService.playClick();
                _nextRound();
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinal() {
    final sorted = _scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final winner = sorted.first.key;
    return _scaffold(
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '🏆 ${_players[winner]} كسب!',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 14),
              _scoreBoard(),
              const SizedBox(height: 24),
              _bigButton('العبوا تاني 🔄', () {
                AudioService.playClick();
                setState(() => _phase = _FPhase.intro);
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- bits

  Widget _scoreBoard() {
    final sorted = _scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FlatColors.ink, width: 2),
      ),
      child: Column(
        children: [
          for (final e in sorted)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${e.value} ⭐',
                    style: flatCairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: FlatColors.ink,
                    ),
                  ),
                  Text(
                    _players[e.key],
                    style: flatCairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: FlatColors.ink,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _bigButton(
    String label,
    VoidCallback onTap, {
    Color? color,
    Color? textColor,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? FlatColors.mintDark,
          foregroundColor: textColor ?? Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: color == Colors.white
                ? const BorderSide(color: FlatColors.ink, width: 2)
                : BorderSide.none,
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: flatCairo(fontSize: 17, fontWeight: FontWeight.w900),
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }
}

class _MasterpiecePainter extends CustomPainter {
  _MasterpiecePainter({required this.strokes, this.current});

  final List<_Stroke> strokes;
  final _Stroke? current;

  @override
  void paint(Canvas canvas, Size size) {
    void drawStroke(_Stroke s) {
      if (s.points.length < 2) return;
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
      for (var i = 1; i < s.points.length; i++) {
        path.lineTo(s.points[i].dx, s.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    for (final s in strokes) {
      drawStroke(s);
    }
    if (current != null) drawStroke(current!);
  }

  @override
  bool shouldRepaint(covariant _MasterpiecePainter oldDelegate) => true;
}
