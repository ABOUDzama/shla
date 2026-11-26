import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../screens/global_player_selection_screen.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/game_intro_widget.dart';
import '../../services/audio_service.dart';
import '../../data/heads_up_data.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';

/// شنطة السفر — the classic cumulative memory chain ("I packed my
/// suitcase..."): players pass the phone in a circle. Each player must say
/// the whole chain OUT LOUD from memory, then add one new item. The app
/// keeps the list and times the turn; the group confirms whether the
/// recital was right. A wrong recital costs a heart (3 hearts = out);
/// last player standing wins. Suggested items from the app's word packs
/// keep the chain funny.
class TravelBagGame extends StatefulWidget {
  const TravelBagGame({super.key});

  @override
  State<TravelBagGame> createState() => _TravelBagGameState();
}

enum _TPhase { recite, add, gameOver }

class _TravelBagGameState extends State<TravelBagGame> {
  final TextEditingController _itemController = TextEditingController();

  bool _showIntro = true;
  bool _started = false;

  List<Map<String, dynamic>> _players = []; // {name, hearts, out}
  int _current = 0;
  final List<String> _chain = [];
  _TPhase _phase = _TPhase.recite;
  int _secondsLeft = 20;
  Timer? _timer;
  String? _entryError;

  List<Map<String, dynamic>> get _alive =>
      _players.where((p) => p['out'] != true).toList();

  List<String> get _suggestions {
    final all = <String>[
      for (final cat in headsUpCategories)
        ...(cat['words'] as List).map((w) => w.toString()),
    ]..shuffle();
    return all.take(3).toList();
  }

  void _start(List<String> names) {
    setState(() {
      _players = names
          .map((n) => {'name': n, 'hearts': 3, 'out': false})
          .toList();
      _current = 0;
      _chain.clear();
      _started = true;
      _phase = _TPhase.recite;
      _startTimer();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = 20;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 5 && _secondsLeft > 0) AudioService.playTick();
      if (_secondsLeft <= 0) {
        t.cancel();
        _mistake(timeout: true);
      }
    });
  }

  void _recitedOk() {
    _timer?.cancel();
    AudioService.playSuccess();
    setState(() => _phase = _TPhase.add);
  }

  void _mistake({bool timeout = false}) {
    _timer?.cancel();
    AudioService.playFailure();
    setState(() {
      final p = _players[_current];
      p['hearts'] = (p['hearts'] as int) - 1;
      if ((p['hearts'] as int) <= 0) p['out'] = true;
      _advance();
    });
  }

  void _addItem() {
    final item = _itemController.text.trim();
    if (item.isEmpty) {
      setState(() => _entryError = 'اكتب الغرض الأول! 🧳');
      return;
    }
    AudioService.playClick();
    setState(() {
      _chain.add(item);
      _entryError = null;
      _itemController.clear();
      _advance();
      _startTimer();
    });
  }

  void _advance() {
    if (_alive.length <= 1) {
      _phase = _TPhase.gameOver;
      AudioService.playWinVoice();
      return;
    }
    do {
      _current = (_current + 1) % _players.length;
    } while (_players[_current]['out'] == true);
    _phase = _TPhase.recite;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _itemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: '🧳 شنطة السفر',
        backgroundColor: FunkyColors.orange,
        body: GameIntroWidget(
          title: '🧳 شنطة السفر',
          icon: '🧳',
          description:
              'لعبة الذاكرة الحلقية!\n\n🗣️ كل واحد في دوره يقول الشنطة كلها بصوت عالي من الذاكرة: "شنت في شنطة السفر..." ويكمّل كل الأغراض بالترتيب، وبعدين يضيف غرض جديد.\n\n❌ نسيت أو لخبطت؟ بتخسر قلب ❤️ (عندك 3).\n⏱️ وعندك 20 ثانية بس!\n\nآخر واحد واقف هو الكسبان.',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }

    if (!_started) {
      return GlobalPlayerSelectionScreen(
        gameTitle: '🧳 شنطة السفر',
        minPlayers: 2,
        maxPlayers: 8,
        onStartGame: (ctx, selected) => _start(selected),
      );
    }

    if (_phase == _TPhase.gameOver) return _buildGameOver();
    if (_phase == _TPhase.recite) return _buildRecite();
    return _buildAdd();
  }

  Widget _heartsRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: _players.map((p) {
        final hearts = p['hearts'] as int;
        final out = p['out'] == true;
        final active = _players.indexOf(p) == _current;
        return Opacity(
          opacity: out ? 0.4 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: active ? FlatColors.mintDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: FlatColors.ink, width: 2),
            ),
            child: Text(
              '${p['name']} ${'❤️' * hearts}${out ? ' 💀' : ''}',
              style: flatCairo(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : FlatColors.ink,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecite() {
    final name = _players[_current]['name'] as String;
    return OfflineGameScaffold(
      title: '🧳 شنطة السفر',
      backgroundColor: FunkyColors.orange,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _heartsRow(),
              const SizedBox(height: 14),
              Text(
                'في الشنطة ${_chain.length} غرض',
                style: flatCairo(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: FlatColors.ink.withValues(alpha: 0.65),
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 6),
              Text(
                '$_secondsLeft ⏱️',
                style: flatCairo(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: _secondsLeft > 5 ? FlatColors.ink : FlatColors.mafia,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: FlatColors.ink, width: 3),
                ),
                child: Column(
                  children: [
                    Text(
                      '$name، قول الشنطة كلها بصوت عالي! 🗣️',
                      textAlign: TextAlign.center,
                      style: flatCairo(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: FlatColors.ink,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '"شنت في شنطة السفر..." وكمّل الـ ${_chain.length} غرض بالترتيب',
                      textAlign: TextAlign.center,
                      style: flatCairo(
                        fontSize: 15,
                        color: FlatColors.ink.withValues(alpha: 0.75),
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _mistake,
                      icon: const Icon(Icons.close, size: 26),
                      label: Text(
                        'غلط! ❌',
                        style: flatCairo(
                          fontSize: 20,
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
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _recitedOk,
                      icon: const Icon(Icons.check, size: 26),
                      label: Text(
                        'قالها صح ✅',
                        style: flatCairo(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlatColors.mintDark,
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
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _timer?.cancel();
                  showDialog(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      backgroundColor: FlatColors.bg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: const BorderSide(color: FlatColors.ink, width: 3),
                      ),
                      title: Text(
                        'الشنطة للتأكد بس! 👀',
                        textAlign: TextAlign.center,
                        style: flatCairo(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      content: Text(
                        _chain.isEmpty
                            ? 'لسه فاضية'
                            : _chain
                                  .asMap()
                                  .entries
                                  .map((e) => '${e.key + 1}. ${e.value}')
                                  .join('\n'),
                        textAlign: TextAlign.right,
                        style: flatCairo(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      actionsAlignment: MainAxisAlignment.center,
                      actions: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(dCtx);
                            _startTimer();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FlatColors.mintDark,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            'اخفيها تاني 🙈',
                            style: flatCairo(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                child: Text(
                  'تحقق من الشنطة (للمجموعة بس)',
                  style: flatCairo(
                    fontSize: 13,
                    color: FlatColors.ink.withValues(alpha: 0.6),
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdd() {
    final name = _players[_current]['name'] as String;
    final sugg = _suggestions.take(3).toList();
    return OfflineGameScaffold(
      title: '🧳 شنطة السفر',
      backgroundColor: FunkyColors.orange,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _heartsRow(),
              const SizedBox(height: 16),
              Text(
                '$name، ضيف غرض جديد 🧳',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 10),
              Text(
                'اقتراحات لو مخك وقف:',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 13,
                  color: FlatColors.ink.withValues(alpha: 0.6),
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: sugg
                    .map(
                      (sug) => GestureDetector(
                        onTap: () {
                          AudioService.playClick();
                          _itemController.text = sug;
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: FlatColors.ink, width: 2),
                          ),
                          child: Text(
                            sug,
                            style: flatCairo(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: FlatColors.ink,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _itemController,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: flatCairo(fontSize: 22, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: 'الغرض الجديد...',
                  hintStyle: flatCairo(
                    fontSize: 18,
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
                onSubmitted: (_) => _addItem(),
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
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _addItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlatColors.mintDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'رميه في الشنطة! 🧳',
                  style: flatCairo(fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameOver() {
    final winner = _alive.isNotEmpty ? _alive.first : null;
    return OfflineGameScaffold(
      title: '🧳 شنطة السفر',
      backgroundColor: FunkyColors.orange,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '🏆',
                style: TextStyle(fontSize: 72),
              ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
              const SizedBox(height: 10),
              Text(
                winner != null
                    ? '${winner['name']} آخر واحد واقف!'
                    : 'مفيش كسبان!',
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
                'الشنطة وصلت لـ ${_chain.length} غرض 🧳',
                style: flatCairo(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: FlatColors.mintDark,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () {
                  AudioService.playClick();
                  _timer?.cancel();
                  setState(() {
                    _started = false;
                    _players = [];
                    _chain.clear();
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
