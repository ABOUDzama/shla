import 'package:flutter/material.dart';
import '../models/game_model.dart';
import '../games/offline/quiz_game.dart';
import '../games/offline/tick_tock_boom.dart';
import '../games/offline/multi_touch_screen.dart';
import '../games/offline/balance_game.dart';
import '../games/offline/five_seconds_game.dart';

import '../games/offline/reverse_quiz.dart';
import '../games/offline/odd_one_out.dart';
import '../games/offline/first_letter_game.dart';
import '../games/offline/opposite_day.dart';
import '../games/offline/xo_game.dart';
import '../games/offline/seega_game.dart';
import '../games/offline/who_am_i_game.dart';
import '../games/offline/word_chain_game.dart';
import '../games/offline/truth_or_dare_game.dart';

import '../games/offline/pictionary_game.dart';
import '../games/offline/charades_game.dart';
import '../games/offline/gobblet_game.dart';
import '../games/offline/truth_or_lie_game.dart';
import '../games/offline/ranking_challenge_game.dart';

import '../games/offline/bus_complete_game.dart';
import '../games/offline/most_likely_game.dart';
import '../games/offline/taboo_game.dart';
import '../games/offline/memory_game.dart';
import '../games/offline/emoji_guess_game.dart';
import '../games/offline/password_game.dart';
import '../games/offline/spy_game.dart';
import '../games/offline/undercover_game.dart';
import '../games/offline/proverb_game.dart';
import '../games/offline/who_said_game.dart';
import '../theme/funky_theme.dart';

class GameRegistry {
  static const List<GameModel> games = [
    GameModel(
      title: 'إكس أو',
      description: 'لعبة إكس أو الكلاسيكية',
      icon: Icons.close,
      color: FunkyColors.mint,
      screen: TicTacToeGame(),
    ),
    GameModel(
      title: 'السيجة',
      description: 'لعبة السيجة الشعبية 3x3',
      icon: Icons.grid_3x3,
      color: FunkyColors.orange,
      screen: SeegaGame(),
    ),
    GameModel(
      title: 'جوبلت',
      description: 'تيك تاك تو بس الأحجام بتفرق! الكبير ياكل الصغير',
      icon: Icons.smart_toy,
      color: FunkyColors.pink,
      screen: GobbletGame(),
    ),
    GameModel(
      title: 'لعبة الأسئلة',
      description: 'أسئلة في مختلف المجالات مع تسجيل النقاط',
      icon: Icons.quiz,
      color: FunkyColors.amber,
      screen: QuizGame(),
    ),
    GameModel(
      title: 'قنبلة الحروف',
      description: 'قول كلمة قبل ما الموبايل ينفجر!',
      icon: Icons.timer,
      color: FunkyColors.coral,
      screen: TickTockBoom(),
    ),
    GameModel(
      title: 'تحدي اللمس',
      description: 'كل واحد يحط صباعه والتطبيق يختار واحد',
      icon: Icons.touch_app,
      color: FunkyColors.mint,
      screen: MultiTouchScreen(),
    ),
    GameModel(
      title: 'تحدي التوازن',
      description: 'حافظ على توازن الكرة أطول فترة ممكنة',
      icon: Icons.balance,
      color: FunkyColors.cyan,
      screen: BalanceGame(),
    ),
    GameModel(
      title: 'تحدي الـ ٥ ثواني',
      description: 'جاوب على السؤال في 5 ثواني بس',
      icon: Icons.speed,
      color: FunkyColors.magenta,
      screen: FiveSecondsGame(),
    ),
    GameModel(
      title: 'الأسئلة المعكوسة',
      description: 'الإجابة موجودة، خمن السؤال!',
      icon: Icons.swap_horiz,
      color: FunkyColors.mint,
      screen: ReverseQuiz(),
    ),
    GameModel(
      title: 'طلع الغريب',
      description: 'مين الدخيل من الأربعة؟',
      icon: Icons.filter_3,
      color: FunkyColors.coral,
      screen: OddOneOut(),
    ),
    GameModel(
      title: 'أول حرف',
      description: 'قول كلمة بتبدأ بالحرف ده!',
      icon: Icons.font_download,
      color: FunkyColors.orange,
      screen: FirstLetterGame(),
    ),
    GameModel(
      title: 'عكس العكاس',
      description: 'أجب بإجابة غلط بسرعة!',
      icon: Icons.flip,
      color: FunkyColors.lime,
      screen: OppositeDay(),
    ),
    GameModel(
      title: 'مين أنا؟',
      description: 'خمّن الشخصية من التلميحات!',
      icon: Icons.person_search,
      color: FunkyColors.sky,
      screen: WhoAmIGame(),
    ),
    GameModel(
      title: 'سلسلة الكلمات',
      description: 'عرّف الكلمة بدون ما تقولها في 60 ثانية!',
      icon: Icons.record_voice_over,
      color: FunkyColors.lime,
      screen: WordChainGame(),
    ),
    GameModel(
      title: 'صراحة ولا جرأة',
      description: 'اللعبة الكلاسيكية للتحدي والصراحة',
      icon: Icons.casino,
      color: FunkyColors.magenta,
      screen: TruthOrDareGame(),
    ),
    GameModel(
      title: 'ارسم وخمّن',
      description: 'ارسم بصباعك والثاني يخمّن!',
      icon: Icons.brush,
      color: FunkyColors.sky,
      screen: PictionaryGame(),
    ),
    GameModel(
      title: 'تمثيل صامت',
      description: 'مثّل الكلمة بدون ما تتكلم!',
      icon: Icons.theater_comedy,
      color: FunkyColors.violet,
      screen: CharadesGame(),
    ),
    GameModel(
      title: 'حقيقة أو هبد',
      description: 'حقائق مدهشة بتظهر شوية شوية.. حقيقة ولا هبد؟',
      icon: Icons.lightbulb_outline,
      color: FunkyColors.cyan,
      screen: TruthOrLieGame(),
    ),
    GameModel(
      title: 'تحدي الترتيب',
      description: 'اكتب موضوع والـ AI يرتبهم سريًا، خمّن ترتيبهم!',
      icon: Icons.leaderboard_rounded,
      color: FunkyColors.coral,
      screen: RankingChallengeGame(),
    ),
    GameModel(
      title: 'أتوبيس كومبليت',
      description: 'لعبة الأتوبيس الشهيرة: ولد، بنت، جماد...',
      icon: Icons.directions_bus_rounded,
      color: FunkyColors.amber,
      screen: BusCompleteGame(),
    ),
    GameModel(
      title: 'مين فينا؟',
      description: 'مين أكتر واحد في الشلة ممكن يعمل كده؟ صوّتوا!',
      icon: Icons.how_to_vote_rounded,
      color: FunkyColors.lime,
      screen: MostLikelyGame(),
    ),
    GameModel(
      title: 'كلمات ممنوعة',
      description: 'وصّف الكلمة من غير ما تقول الممنوع!',
      icon: Icons.block_rounded,
      color: FunkyColors.coral,
      screen: TabooGame(),
    ),
    GameModel(
      title: 'ذاكرة الشلة',
      description: 'افتح كارتين متشابهين واجمع أكتر أزواج!',
      icon: Icons.psychology_rounded,
      color: FunkyColors.sky,
      screen: MemoryGame(),
    ),
    GameModel(
      title: 'مين قالها؟',
      description: 'إجابة سرية والشلة تخمن صاحبها!',
      icon: Icons.record_voice_over_rounded,
      color: FunkyColors.mint,
      screen: WhoSaidGame(),
      badge: 'جديد',
    ),
    GameModel(
      title: 'أكمل المثل',
      description: 'كمّل المثل الشعبي صح قبل ما حد يسرقها منك!',
      icon: Icons.menu_book_rounded,
      color: FunkyColors.pink,
      screen: ProverbGame(),
      badge: 'جديد',
    ),
    GameModel(
      title: 'أندر كافر',
      description: 'المدنيين معاهم كلمة والمتسللين شبهها.. اوصف واكشفهم!',
      icon: Icons.groups_rounded,
      color: FunkyColors.violet,
      screen: UndercoverGame(),
      badge: 'جديد',
    ),
    GameModel(
      title: 'الجاسوس',
      description: 'واحد فيكم ميعرفش المكان.. اكشفوه قبل ما يعرفه!',
      icon: Icons.person_search_rounded,
      color: FunkyColors.violet,
      screen: SpyGame(),
      badge: 'جديد',
    ),
    GameModel(
      title: 'كلمة السر',
      description: 'تلميح بكلمة واحدة والباقي يخمنوا كلمة السر',
      icon: Icons.key_rounded,
      color: FunkyColors.amber,
      screen: PasswordGame(),
      badge: 'جديد',
    ),
    GameModel(
      title: 'إيموجي إيه؟',
      description: 'خمّن الكلمة أو الموقف من الإيموجي بس!',
      icon: Icons.emoji_emotions_rounded,
      color: FunkyColors.amber,
      screen: EmojiGuessGame(),
    ),
  ];
}
