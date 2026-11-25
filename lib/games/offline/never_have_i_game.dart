import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../screens/global_player_selection_screen.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/game_intro_widget.dart';
import '../../theme/funky_theme.dart';

/// أنا عمري ما (Never Have I Ever): the classic party confession game.
/// Each turn one player reads the statement out loud; everyone who DID it
/// takes a point (the Shla way: نقطة خبث لكل اعتراف). The app rotates the
/// prompts so nobody repeats, pass-and-play.
class NeverHaveIGame extends StatefulWidget {
  const NeverHaveIGame({super.key, this.seed = 13});

  /// Deterministic seed for tests.
  final int seed;

  static const List<String> statements = [
    'أنا عمري ما كدبت على ماما في حاجة كبيرة',
    'أنا عمري ما نمت في المحاضرة',
    'أنا عمري ما عملت سناب وأنا بسوق',
    'أنا عمري ما وقعت من الفرح',
    'أنا عمري ما بعت رسالة للشخص الغلط',
    'أنا عمري ما فضلت صاحي لحد الفجر ألعب',
    'أنا عمري ما كلت حاجة وقعت على الأرض',
    'أنا عمري ما اتخطفت من فيلم رعب',
    'أنا عمري ما غنيت في الحمام بصوت عالي',
    'أنا عمري ما نسيت عيد ميلاد صاحبي',
    'أنا عمري ما عملت نفسي نايم عشان مكالمة',
    'أنا عمري ما ضحكت في موقف ممنوع الضحك',
    'أنا عمري ما خدت صورة لأكلي قبل ما آكله',
    'أنا عمري ما رجعت من نص الطريق عشان نسيت حاجة',
    'أنا عمري ما اتكلمت مع نفسي بصوت عالي',
    'أنا عمري ما بحثت عن اسمي على جوجل',
    'أنا عمري ما حفظت أغنية مش من جيلي',
    'أنا عمري ما لعبت لعبة ورق على القهوة',
    'أنا عمري ما عيطت على فيلم',
    'أنا عمري ما قلت "وصلت" وأنا لسه في البيت',
    'أنا عمري ما رقصت وأنا لوحدي',
    'أنا عمري ما اتصورت أكتر من ٢٠ مرة في يوم واحد',
    'أنا عمري ما نسيت شاحن الموبايل في سفر',
    'أنا عمري ما حلمت إني بقع',
  ];

  /// Order of statement indices for a session: shuffled, no repeats.
  static List<int> shuffledOrder(Random rng) {
    final order = List.generate(statements.length, (i) => i)..shuffle(rng);
    return order;
  }

  @override
  State<NeverHaveIGame> createState() => _NeverHaveIGameState();
}

class _NeverHaveIGameState extends State<NeverHaveIGame> {
  late final Random _rng = Random(widget.seed);
  bool _showIntro = true;
  bool _started = false;

  List<String> _names = [];
  late List<int> _order;
  Map<String, int> _confessions = {};
  int _turn = 0;

  int get _maxTurns => _names.isEmpty ? 0 : _names.length * 3;

  String get _reader => _names[_turn % _names.length];

  void _start(List<String> names) {
    setState(() {
      _names = names;
      _order = NeverHaveIGame.shuffledOrder(_rng);
      _confessions = {for (final n in names) n: 0};
      _turn = 0;
      _started = true;
    });
  }

  void _mark(String name, bool didIt) {
    setState(() {
      if (didIt) _confessions[name] = (_confessions[name] ?? 0) + 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: '✋ أنا عمري ما',
        backgroundColor: FunkyColors.pink,
        showAi: false,
        body: GameIntroWidget(
          title: '✋ أنا عمري ما',
          icon: '✋',
          description:
              'لعبة الاعترافات الأشهر في الجلسات: واحد يقرا الجملة بصوت عالي، وكل اللي عملها يعترف وياخد نقطة خبث. اللي اعترف أكتر.. ده اللي عايش حياته صح! التصويت والاعتراف بيحصل بصوتكم، والتطبيق بيدير الجمل والنقاط.',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }

    if (!_started) {
      return GlobalPlayerSelectionScreen(
        gameTitle: '✋ أنا عمري ما',
        minPlayers: 2,
        onStartGame: (ctx, selected) => _start(selected),
      );
    }

    if (_turn >= _maxTurns || _turn >= _order.length) return _buildEnd();

    final statement = _order[_turn];
    return OfflineGameScaffold(
      title: '✋ أنا عمري ما',
      backgroundColor: FunkyColors.pink,
      showAi: false,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'الجملة ${_turn + 1} - القارئ: $_reader',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  GoogleFonts.cairo(fontSize: 14, color: Colors.white60),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration:
                  FunkyDecor.glowCard(FunkyColors.pink, radius: 26),
              child: Text(
                NeverHaveIGame.statements[statement],
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ).animate(key: ValueKey(_turn)).scale(duration: 300.ms),
            ),
            const SizedBox(height: 14),
            Text(
              'مين عملها؟ دوس على اسمه لكل اعتراف:',
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.cairo(fontSize: 14, color: Colors.white70)
                      .copyWith(
                          fontFamilyFallback: const ['Noto Color Emoji']),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: _names.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final n = _names[i];
                  return GestureDetector(
                    onTap: () => _mark(n, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      decoration: FunkyDecor.glowCard(FunkyColors.mint,
                          radius: 18),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              n,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Text(
                            '${_confessions[n]} اعتراف',
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            FunkyButton(
              label: 'الجملة اللي بعدها ⏭',
              accent: FunkyColors.pink,
              icon: Icons.arrow_forward_rounded,
              onPressed: () => setState(() => _turn++),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnd() {
    final sorted = _confessions.keys.toList()
      ..sort((a, b) => _confessions[b]!.compareTo(_confessions[a]!));
    return OfflineGameScaffold(
      title: '✋ أنا عمري ما',
      backgroundColor: FunkyColors.pink,
      showAi: false,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'نتيجة الاعترافات! 🎉',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
            ),
            const SizedBox(height: 20),
            for (final n in sorted)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '$n: ${_confessions[n]} اعتراف',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 17,
                    color: Colors.white70,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            FunkyButton(
              label: 'العب تاني',
              accent: FunkyColors.mint,
              icon: Icons.refresh_rounded,
              onPressed: () => setState(() {
                _started = false;
                _showIntro = true;
              }),
            ),
          ],
        ),
      ),
    );
  }
}
