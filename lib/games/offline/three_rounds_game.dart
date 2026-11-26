import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../../screens/global_player_selection_screen.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/game_intro_widget.dart';
import '../../services/audio_service.dart';
import '../../data/heads_up_data.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';

/// ثلاث جولات — exact clone of Time's Up! (R&R Games official rules):
/// one shared "Deck of Fame" is played over THREE rounds:
///   Round 1: the cluegiver may say almost anything — no passing.
///   Round 2: only ONE word per card, ONE guess per card — passing allowed.
///   Round 3: no words at all, pantomime and sounds only — passing allowed.
/// Each turn is 30 seconds. Passed / wrong-guess cards are set aside and
/// shuffled back into the deck at the end of the turn. A round ends the
/// moment the deck is exhausted; every guessed card is 1 point. The team
/// that emptied the deck may start the next round with its remaining time
/// or hand a fresh 30 seconds to the next team. Highest total after three
/// rounds wins.
class ThreeRoundsGame extends StatefulWidget {
  const ThreeRoundsGame({super.key});

  static const int deckSize = 40;
  static const int turnSeconds = 30;

  @override
  State<ThreeRoundsGame> createState() => _ThreeRoundsGameState();
}

enum _TPhase {
  intro,
  players,
  teams,
  roundIntro,
  turnReady,
  play,
  turnEnd,
  roundEnd,
  carryChoice,
  finalResults,
}

class _ThreeRoundsGameState extends State<ThreeRoundsGame> {
  _TPhase _phase = _TPhase.intro;
  final Random _rng = Random();

  List<List<String>> _teams = [];
  final List<int> _teamScores = [0, 0];
  final List<int> _clueIdx = [0, 0];
  int _currentTeam = 0;

  List<String> _deck = [];
  final List<String> _setAside = [];
  String _currentCard = '';
  int _turnGuessed = 0;
  final List<int> _roundScores = [0, 0];

  int _round = 1;
  int _secondsLeft = ThreeRoundsGame.turnSeconds;
  int _carrySeconds = 0;
  Timer? _timer;

  static const List<Color> _teamColors = [FunkyColors.cyan, FunkyColors.coral];
  static const List<String> _teamEmojis = ['🐯', '🦁'];

  // ---------------------------------------------------------------- flow

  void _start(List<String> names) {
    final shuffled = List<String>.from(names)..shuffle(_rng);
    _teams = [[], []];
    for (var i = 0; i < shuffled.length; i++) {
      _teams[i % 2].add(shuffled[i]);
    }
    _teamScores[0] = 0;
    _teamScores[1] = 0;
    _clueIdx[0] = 0;
    _clueIdx[1] = 0;
    _currentTeam = 0;
    _round = 1;
    _buildDeck();
    AudioService.playClick();
    setState(() => _phase = _TPhase.teams);
  }

  void _buildDeck() {
    final pool = <String>{};
    for (final cat in headsUpCategories) {
      for (final w in (cat['words'] as List).cast<String>()) {
        pool.add(w);
      }
    }
    final list = pool.toList()..shuffle(_rng);
    _deck = list.take(ThreeRoundsGame.deckSize).toList();
    // The same 40 names come back every round (official Deck of Fame).
    _fameCards = List<String>.from(_deck);
    _setAside.clear();
  }

  String get _cluegiver => _teams[_currentTeam][_clueIdx[_currentTeam]];

  void _startTurn({int? seconds}) {
    _turnGuessed = 0;
    _secondsLeft = seconds ?? ThreeRoundsGame.turnSeconds;
    _drawNext();
    AudioService.playClick();
    setState(() => _phase = _TPhase.play);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 5 && _secondsLeft > 0) AudioService.playTick();
        if (_secondsLeft <= 0) {
          _endTurn();
        }
      });
    });
  }

  void _drawNext() {
    if (_deck.isEmpty) return;
    _currentCard = _deck.removeLast();
  }

  void _onCorrect() {
    AudioService.playSuccess();
    _turnGuessed++;
    _roundScores[_currentTeam]++;
    if (_deck.isEmpty) {
      _onDeckEmpty();
      return;
    }
    setState(_drawNext);
  }

  void _onSetAside() {
    // Pass (rounds 2-3) or wrong guess: card goes aside, back into the deck
    // at the end of the turn — exactly like the box rules.
    AudioService.playFailure();
    _setAside.add(_currentCard);
    if (_deck.isEmpty) {
      // Finished the deck mid-turn: turn ends, aside cards return.
      _endTurn();
      return;
    }
    setState(_drawNext);
  }

  void _endTurn() {
    _timer?.cancel();
    // Unguessed current card + set-aside cards shuffle back into the deck.
    if (_deck.isNotEmpty || _currentCard.isNotEmpty) {
      _deck.add(_currentCard);
    }
    _deck.addAll(_setAside);
    _setAside.clear();
    _deck.shuffle(_rng);
    _clueIdx[_currentTeam] =
        (_clueIdx[_currentTeam] + 1) % _teams[_currentTeam].length;
    _currentTeam = (_currentTeam + 1) % _teams.length;
    AudioService.playFailure();
    setState(() => _phase = _TPhase.turnEnd);
  }

  void _onDeckEmpty() {
    _timer?.cancel();
    _carrySeconds = _secondsLeft;
    AudioService.playWinVoice();
    setState(() => _phase = _TPhase.roundEnd);
  }

  void _nextRound() {
    _teamScores[0] += _roundScores[0];
    _teamScores[1] += _roundScores[1];
    _roundScores[0] = 0;
    _roundScores[1] = 0;
    if (_round >= 3) {
      setState(() => _phase = _TPhase.finalResults);
      return;
    }
    _round++;
    // Rebuild the deck from the SAME cards (official: all names go back).
    _buildDeckFromCurrent();
    setState(() => _phase = _TPhase.carryChoice);
  }

  late List<String> _fameCards = [];

  void _buildDeckFromCurrent() {
    _deck = List<String>.from(_fameCards)..shuffle(_rng);
    _setAside.clear();
  }

  void _carryContinue() {
    // The team that emptied the deck starts the next round with its
    // remaining seconds (official carry-over rule).
    AudioService.playClick();
    setState(() => _phase = _TPhase.turnReady);
    _pendingSeconds = _carrySeconds > 0 ? _carrySeconds : 1;
  }

  void _carryPass() {
    // Hand the first turn to the next team with a fresh 30 seconds.
    _currentTeam = (_currentTeam + 1) % _teams.length;
    AudioService.playClick();
    setState(() => _phase = _TPhase.turnReady);
    _pendingSeconds = ThreeRoundsGame.turnSeconds;
  }

  int? _pendingSeconds;

  // ---------------------------------------------------------------- build

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _TPhase.intro:
        return OfflineGameScaffold(
          title: '⏱️ ثلاث جولات',
          backgroundColor: FunkyColors.violet,
          body: GameIntroWidget(
            title: 'ثلاث جولات 🎭',
            icon: '⏱️',
            description:
                'لعبة Time\'s Up الأصلية!\n\n'
                '🃏 40 اسم مشهور أو حاجة في دك واحد يتلف 3 جولات.\n'
                '1️⃣ الجولة 1: اوصف بأي كلام.. بس ممنوع تقول جزء من الاسم، وممنوع تخطي!\n'
                '2️⃣ الجولة 2: نفس الأسماء.. بس كلمة واحدة لكل كارت، وتخمينة واحدة بس!\n'
                '3️⃣ الجولة 3: ممنوع الكلام خالص.. تمثيل وأصوات بس!\n\n'
                '⏱️ كل دور 30 ثانية. كل كارت متخمّن = نقطة. اللي يخلّص الدك يكمل أول دور الجولة الجاية بالوقت الباقي!',
            onStart: () {
              AudioService.playClick();
              setState(() => _phase = _TPhase.players);
            },
          ),
        );
      case _TPhase.players:
        return GlobalPlayerSelectionScreen(
          gameTitle: '⏱️ ثلاث جولات',
          minPlayers: 4,
          maxPlayers: 10,
          onStartGame: (ctx, selected) => _start(selected),
        );
      case _TPhase.teams:
        return _buildTeams();
      case _TPhase.roundIntro:
        return _buildRoundIntro();
      case _TPhase.turnReady:
        return _buildTurnReady();
      case _TPhase.play:
        return _buildPlay();
      case _TPhase.turnEnd:
        return _buildTurnEnd();
      case _TPhase.roundEnd:
        return _buildRoundEnd();
      case _TPhase.carryChoice:
        return _buildCarryChoice();
      case _TPhase.finalResults:
        return _buildFinal();
    }
  }

  Widget _scaffold(Widget body) => OfflineGameScaffold(
    title: '⏱️ ثلاث جولات',
    backgroundColor: FunkyColors.violet,
    body: body,
  );

  Widget _buildTeams() {
    return _scaffold(
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              'الفرق اتقسمت بالتساوي 👥',
              style: flatCairo(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: FlatColors.ink,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                children: List.generate(2, (t) {
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(
                        left: t == 0 ? 6 : 0,
                        right: t == 1 ? 6 : 0,
                      ),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _teamColors[t], width: 3),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${_teamEmojis[t]} فريق ${t + 1}',
                            style: flatCairo(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _teamColors[t],
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: ListView(
                              children: _teams[t]
                                  .map(
                                    (n) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: Text(
                                        n,
                                        textAlign: TextAlign.center,
                                        style: flatCairo(
                                          fontSize: 16,
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
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            _bigButton('يلا نبدأ الجولة 1! 🚀', () {
              AudioService.playClick();
              setState(() => _phase = _TPhase.roundIntro);
            }),
          ],
        ),
      ),
    );
  }

  static const _roundInfo = {
    1: (
      '🗣️ الجولة 1',
      'اوصف بأي كلام!\nممنوع تقول جزء من الاسم أو تهجّيه..\nوممنوع تخطي الكارت!',
    ),
    2: (
      '☝️ الجولة 2',
      'نفس الأسماء تاني..\nبس كلمة واحدة لكل كارت!\nوتخمينة واحدة بس.. التخطي مسموح.',
    ),
    3: (
      '🎭 الجولة 3',
      'نفس الأسماء آخر مرة..\nممنوع الكلام خالص!\nتمثيل وأصوات بس.. والتخطي مسموح.',
    ),
  };

  Widget _buildRoundIntro() {
    final info = _roundInfo[_round]!;
    return _scaffold(
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: FlatColors.ink, width: 2.5),
                ),
                child: Column(
                  children: [
                    Text(
                      info.$1,
                      style: flatCairo(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: FlatColors.ink,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      info.$2,
                      textAlign: TextAlign.center,
                      style: flatCairo(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: FlatColors.ink,
                        height: 1.7,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _bigButton('فهمنا! يلا 💪', () {
                AudioService.playClick();
                setState(() => _phase = _TPhase.turnReady);
                _pendingSeconds = null;
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTurnReady() {
    return _scaffold(
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _scoreStrip(),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _teamColors[_currentTeam],
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: FlatColors.ink, width: 2.5),
                ),
                child: Column(
                  children: [
                    Text(
                      '${_teamEmojis[_currentTeam]} دور فريق ${_currentTeam + 1}',
                      style: flatCairo(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'الموصّف: $_cluegiver\nالفريق كله يخمّن معاه!',
                      textAlign: TextAlign.center,
                      style: flatCairo(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.7,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _bigButton(
                'ابدأ الـ ${_pendingSeconds ?? ThreeRoundsGame.turnSeconds} ثانية! ⏱️',
                () => _startTurn(seconds: _pendingSeconds),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlay() {
    final total = _pendingSeconds ?? ThreeRoundsGame.turnSeconds;
    final frac = (_secondsLeft / total).clamp(0.0, 1.0);
    return _scaffold(
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              '${_teamEmojis[_currentTeam]} فريق ${_currentTeam + 1}  •  $_cluegiver بيوصف  •  الجولة $_round من 3',
              style: flatCairo(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: FlatColors.ink,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 10),
            // Timer bar
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: FlatColors.ink, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FractionallySizedBox(
                        widthFactor: frac,
                        child: Container(
                          color: _secondsLeft <= 5
                              ? FlatColors.mafia
                              : FunkyColors.mint,
                        ),
                      ),
                    ),
                  ),
                ),
                Text(
                  '$_secondsLeft',
                  style: flatCairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: FlatColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // The card
            Expanded(
              child: Center(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: _teamColors[_currentTeam],
                      width: 4,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _currentCard,
                      textAlign: TextAlign.center,
                      style: flatCairo(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: FlatColors.ink,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'اتخمّنوا: $_turnGuessed  •  فاضل في الدك: ${_deck.length + 1}',
              style: flatCairo(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: FlatColors.ink,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_round > 1) ...[
                  Expanded(
                    child: _actionButton(
                      'غلط / تخطي ❌',
                      FlatColors.mafia,
                      _onSetAside,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: _actionButton(
                    'صح! ✅',
                    FlatColors.mintDark,
                    _onCorrect,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurnEnd() {
    return _scaffold(
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '⏰ خلص الوقت!',
                style: flatCairo(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 12),
              Text(
                'فريق ${_currentTeam == 0 ? 2 : 1} خمّن $_turnGuessed كارت في الدور ده',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 8),
              Text(
                'الكروت اللي متخمّنتش رجعت الدك 🔀',
                style: flatCairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 24),
              _bigButton('الدور اللي بعده ⏭️', () {
                AudioService.playClick();
                setState(() {
                  _phase = _TPhase.turnReady;
                  _pendingSeconds = null;
                });
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoundEnd() {
    return _scaffold(
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '🏁 الجولة $_round خلصت!',
                style: flatCairo(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 16),
              _scoreStrip(big: true),
              const SizedBox(height: 12),
              Text(
                'الجولة دي: 🐯 ${_roundScores[0]}  -  🦁 ${_roundScores[1]}',
                style: flatCairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 24),
              _bigButton(
                _round >= 3
                    ? 'النتيجة النهائية! 🏆'
                    : 'الجولة ${_round + 1} ⏭️',
                () {
                  AudioService.playClick();
                  _nextRound();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarryChoice() {
    return _scaffold(
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '⏱️ فريق ${_currentTeam + 1} خلّص الدك\nومعاه $_carrySeconds ثانية فاضلة!',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                  height: 1.7,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 10),
              Text(
                'يكمل أول دور الجولة $_round بالوقت الباقي..\nولا يديها للفريق التاني بـ 30 ثانية كاملة؟',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: FlatColors.ink,
                  height: 1.7,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 24),
              _bigButton('اكمل بـ $_carrySeconds ثانية ⚡', _carryContinue),
              const SizedBox(height: 12),
              _bigButton(
                'عدّيها للفريق التاني 🤝',
                _carryPass,
                color: FlatColors.mintDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinal() {
    final winner = _teamScores[0] == _teamScores[1]
        ? -1
        : (_teamScores[0] > _teamScores[1] ? 0 : 1);
    return _scaffold(
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                winner == -1
                    ? '🤝 تعادل!'
                    : '🏆 فريق ${winner + 1} ${_teamEmojis[winner]} كسب!',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 16),
              _scoreStrip(big: true),
              const SizedBox(height: 24),
              _bigButton('العبوا تاني 🔄', () {
                AudioService.playClick();
                _timer?.cancel();
                setState(() => _phase = _TPhase.intro);
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- bits

  Widget _scoreStrip({bool big = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: big ? 14 : 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FlatColors.ink, width: 2),
      ),
      child: Text(
        '🐯 ${_teamScores[0] + _roundScores[0]}  :  ${_teamScores[1] + _roundScores[1]} 🦁',
        style: flatCairo(
          fontSize: big ? 26 : 18,
          fontWeight: FontWeight.w900,
          color: FlatColors.ink,
        ),
        textDirection: TextDirection.rtl,
      ),
    );
  }

  Widget _bigButton(String label, VoidCallback onTap, {Color? color}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? FlatColors.mintDark,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: flatCairo(fontSize: 18, fontWeight: FontWeight.w900),
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: FlatColors.ink, width: 2),
        ),
        elevation: 0,
      ),
      child: Text(
        label,
        style: flatCairo(fontSize: 18, fontWeight: FontWeight.w900),
        textDirection: TextDirection.rtl,
      ),
    );
  }
}
