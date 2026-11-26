import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/game_model.dart';
import '../../services/cup_service.dart';
import '../../services/game_registry.dart';
import '../../services/results_service.dart';
import '../../theme/flat_theme.dart';
import '../../widgets/victory_friends.dart';
import 'cup_setup_screen.dart';
import '../arcade_section_screen.dart';

/// كأس الشلة home: the standings board, the current round, and the
/// champion celebration when the last round is done.
///
/// The cup never touches the games: it pushes the round's game screen, and
/// listens to [ResultsService] for the winner the game's own victory screen
/// records. Coming back with no result recorded means the round was left
/// early — the cup offers replay or skip, honest and explicit.
class CupScreen extends StatefulWidget {
  const CupScreen({super.key, this.embedded = false});

  /// When true, renders as a home tab: no back button and extra bottom
  /// padding so the floating nav bar never covers the content.
  final bool embedded;

  @override
  State<CupScreen> createState() => _CupScreenState();
}

class _CupScreenState extends State<CupScreen> {
  static const _emojiFallback = ['Noto Color Emoji'];
  bool _busy = false;

  CupService get cup => CupService.instance;

  @override
  void initState() {
    super.initState();
    unawaited(cup.restore().then((_) {
      if (mounted) setState(() {});
    }));
    ResultsService.instance.addListener(_onResults);
  }

  @override
  void dispose() {
    ResultsService.instance.removeListener(_onResults);
    super.dispose();
  }

  Future<void> _onResults() async {
    final all = await ResultsService.instance.load();
    await cup.ingestResults(all);
    if (mounted) setState(() {});
  }

  GameModel? _modelFor(String title) {
    for (final g in GameRegistry.games) {
      if (g.title == title) return g;
    }
    return null;
  }

  Future<void> _playRound() async {
    final title = cup.currentGame;
    if (title == null || _busy) return;
    final model = _modelFor(title);
    if (model == null) return;
    _busy = true;
    await cup.markRoundStarted();
    if (!mounted) return;
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => model.screen));
    _busy = false;
    if (!mounted) return;
    // Back from the game. A recorded win already advanced the cup via the
    // ResultsService listener; still open means the round was left early.
    if (cup.roundOpen) {
      await _unfinishedSheet();
    }
    setState(() {});
  }

  Future<void> _unfinishedSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: FlatColors.tileWhite,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('الجولة مخلصتش 🤔',
                  style: _t(18, w: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                'مفيش نتيجة اتسجلت من اللعبة. تحبوا إيه؟',
                textAlign: TextAlign.center,
                style: _t(13, w: FontWeight.w700)
                    .copyWith(color: FlatColors.ink.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _playRound();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlatColors.tilePastels[2],
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('العبوا الجولة', style: _t(15, w: FontWeight.w900, c: Colors.white)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await cup.skipRound();
                    if (mounted) setState(() {});
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FlatColors.ink,
                    side: const BorderSide(color: FlatColors.border, width: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('تخطي الجولة من غير نقاط',
                      style: _t(15, w: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _endCup() async {
    await cup.endCup();
    if (mounted) Navigator.pop(context);
  }

  TextStyle _t(double size,
          {FontWeight w = FontWeight.w800, Color? c, double? h}) =>
      GoogleFonts.cairo(
        fontSize: size,
        fontWeight: w,
        color: c ?? FlatColors.ink,
        height: h,
      ).copyWith(fontFamilyFallback: _emojiFallback);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: cup,
      builder: (context, _) {
        if (!cup.active) {
          return Scaffold(
            backgroundColor: FlatColors.bg,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('مفيش كأس شغال دلوقتي',
                        style: _t(16, w: FontWeight.w900)),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CupSetupScreen()),
                      ),
                      child: Text('ابدأ كأس جديد 🏆',
                          style: _t(15,
                              w: FontWeight.w900, c: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return Scaffold(
          backgroundColor: FlatColors.bg,
          body: SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 12, 20, widget.embedded ? 130 : 24),
              children: [
                Row(
                  children: [
                    if (!widget.embedded)
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: FlatColors.ink),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: _endCup,
                      child: Text('إنهاء الكأس',
                          style: _t(12, w: FontWeight.w800)
                              .copyWith(color: Colors.redAccent)),
                    ),
                  ],
                ),
                Center(
                  child: Text('كأس الشلة 🏆',
                      style: _t(26, w: FontWeight.w900)),
                ),
                Center(
                  child: Text(
                    cup.finished
                        ? 'الكأس خلص!'
                        : 'الجولة ${cup.roundNumber} من ${cup.rounds}',
                    textDirection: TextDirection.rtl,
                    style: _t(13, w: FontWeight.w700)
                        .copyWith(color: FlatColors.ink.withValues(alpha: 0.7)),
                  ),
                ),
                const SizedBox(height: 16),
                if (cup.finished) _championCard() else _roundCard(),
                const SizedBox(height: 20),
                _standingsCard(),
                const SizedBox(height: 20),
                _roundsList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _roundCard() {
    final title = cup.currentGame!;
    final cover = ArcadeSectionScreen.covers[title];
    final emoji = ArcadeSectionScreen.emojiOf(title);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlatColors.tileWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FlatColors.border, width: 2),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 140,
              width: double.infinity,
              child: cover != null
                  ? Image.asset(cover, fit: BoxFit.cover)
                  : Container(
                      color: FlatColors.tilePastels[1].withValues(alpha: 0.2),
                      child: Center(
                          child:
                              Text(emoji, style: const TextStyle(fontSize: 56))),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(title,
              style: _t(20, w: FontWeight.w900),
              textDirection: TextDirection.rtl),
          const SizedBox(height: 4),
          Text(
            'الفايز ياخد نقطة ⭐',
            style: _t(12, w: FontWeight.w700)
                .copyWith(color: FlatColors.ink.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _playRound,
              style: ElevatedButton.styleFrom(
                backgroundColor: FlatColors.tilePastels[3],
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 6),
                  Text('ابدأ الجولة',
                      style: _t(16, w: FontWeight.w900, c: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _championCard() {
    final leaders = cup.leaders;
    final name = leaders.isEmpty
        ? ''
        : leaders.map((e) => e.key).join(' و ');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FlatColors.tileWhite,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: FlatColors.tilePastels[4], width: 3),
      ),
      child: Column(
        children: [
          if (leaders.isEmpty) ...[
            Text('الكأس بلا بطل 🤖',
                style: _t(22, w: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              'ولا لاعب كسب جولة — البوتات مسكوا الشلة المرة دي!',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: _t(13, w: FontWeight.w700)
                  .copyWith(color: FlatColors.ink.withValues(alpha: 0.75)),
            ),
          ] else ...[
            Text(
              leaders.length == 1 ? 'بطل الكأس 👑' : 'أبطال الكأس 👑',
              style: _t(22, w: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            VictoryFriends(
              winnerName: name,
              // The cup already records every round's win through the games
              // themselves; the champion screen celebrates only.
            ),
            const SizedBox(height: 8),
            Text(name, style: _t(20, w: FontWeight.w900)),
            Text(
              '${leaders.first.value} ${leaders.first.value == 1 ? 'نقطة' : 'نقاط'} من ${cup.rounds} جولات',
              style: _t(13, w: FontWeight.w800)
                  .copyWith(color: FlatColors.mintDark),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _endCup,
              style: ElevatedButton.styleFrom(
                backgroundColor: FlatColors.tilePastels[4],
                foregroundColor: FlatColors.ink,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('تم 🏆', style: _t(16, w: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _standingsCard() {
    final standings = cup.standings;
    final leaderNames = cup.leaders.map((e) => e.key).toSet();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlatColors.tileWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FlatColors.border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الترتيب', style: _t(16, w: FontWeight.w900)),
          const SizedBox(height: 8),
          if (standings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'لسه مفيش نقاط — أول جولة هي اللي هتحسم 🔥',
                  style: _t(12, w: FontWeight.w700)
                      .copyWith(color: FlatColors.ink.withValues(alpha: 0.65)),
                ),
              ),
            )
          else
            for (var i = 0; i < standings.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: i == 0
                          ? FlatColors.tilePastels[4]
                          : FlatColors.border,
                      child: Text('${i + 1}',
                          style: _t(13,
                              w: FontWeight.w900,
                              c: i == 0 ? FlatColors.ink : FlatColors.ink)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        standings[i].key +
                            (leaderNames.contains(standings[i].key)
                                ? ' 👑'
                                : ''),
                        style: _t(15, w: FontWeight.w900),
                      ),
                    ),
                    Text('${standings[i].value} ⭐',
                        style: _t(14, w: FontWeight.w900)),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _roundsList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlatColors.tileWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FlatColors.border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الجولات', style: _t(16, w: FontWeight.w900)),
          const SizedBox(height: 8),
          for (var i = 0; i < cup.games.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(
                    i < cup.roundIndex
                        ? Icons.check_circle_rounded
                        : (i == cup.roundIndex
                            ? Icons.play_circle_fill_rounded
                            : Icons.hourglass_empty_rounded),
                    size: 18,
                    color: i < cup.roundIndex
                        ? FlatColors.mintDark
                        : (i == cup.roundIndex
                            ? FlatColors.tilePastels[3]
                            : FlatColors.border),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${i + 1}. ${cup.games[i]}',
                      style: _t(13,
                              w: i == cup.roundIndex
                                  ? FontWeight.w900
                                  : FontWeight.w700)
                          .copyWith(
                              color: i < cup.roundIndex
                                  ? FlatColors.ink.withValues(alpha: 0.55)
                                  : FlatColors.ink),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
