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
import '../games/offline/mafia_game.dart';
import '../games/offline/would_rather_game.dart';
import '../games/offline/word_story_game.dart';
import '../games/offline/code_names_game.dart';
import '../games/offline/never_have_i_game.dart';
import '../games/offline/proverb_game.dart';
import '../games/offline/reaction_game.dart';
import '../games/offline/snake_arena_game.dart';
import '../games/offline/chicken_run_game.dart';
import '../games/offline/car_race_game.dart';
import '../games/offline/pigeon_game.dart';
import '../games/offline/tank_battle_game.dart';
import '../games/offline/tug_of_war_game.dart';
import '../games/offline/snow_brawl_game.dart';
import '../games/offline/coin_grab_game.dart';
import '../games/offline/whack_mole_game.dart';
import '../games/offline/sumo_game.dart';
import '../games/offline/catch_game.dart';
import '../games/offline/tap_race_game.dart';
import '../games/offline/croc_game.dart';
import '../games/offline/flappy_game.dart';
import '../games/offline/minigolf_game.dart';
import '../games/offline/obstacle_game.dart';
import '../games/offline/ludo_game.dart';
import '../games/offline/touch_ball_game.dart';
import '../games/offline/rhythm_game.dart';
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
      description: 'قول كلمة بتبدأ بآخر حرف من كلمة زميلك!',
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
      title: 'مافيا',
      description: 'مافيا خفية بينكم.. ليلًا بتقتل ونهارًا القرية بتحقق!',
      icon: Icons.nightlight_round,
      color: FunkyColors.pink,
      screen: MafiaGame(),
      badge: 'جديد',
    ),
    GameModel(
      title: 'لو خيروك',
      description: 'اختيارين صعبين.. صوّت في السر وشوف مين مع مين!',
      icon: Icons.compare_arrows_rounded,
      color: FunkyColors.amber,
      screen: WouldRatherGame(),
      badge: 'جديد',
    ),
    GameModel(
      title: 'أنا عمري ما',
      description: 'لعبة الاعترافات: اقرا الجملة ومين عملها يعترف!',
      icon: Icons.front_hand_rounded,
      color: FunkyColors.pink,
      screen: NeverHaveIGame(),
      badge: 'جديد',
    ),
    GameModel(
      title: 'كلمة بكلمة',
      description: 'كل واحد يضيف كلمة.. ونشوف القصة هتوصل لفين!',
      icon: Icons.menu_book_rounded,
      color: FunkyColors.mint,
      screen: WordStoryGame(),
      badge: 'جديد',
    ),
    GameModel(
      title: 'الشيفرة',
      description: 'فريقين وشبكة كلمات.. تلميح من كلمة واحدة وخد بالك من القاتل!',
      icon: Icons.grid_on_rounded,
      color: FunkyColors.violet,
      screen: CodeNamesGame(),
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
    GameModel(
      title: 'أسرع رد فعل',
      description: 'الشاشة تقلب خضرا واللي يدوس الأول يكسب! دوس بدري = خصم نقطة',
      icon: Icons.bolt,
      color: FunkyColors.lime,
      screen: ReactionGame(),
      badge: 'جديد',
      arcade1234: true,
    ),
    GameModel(
      title: 'حية الشلة',
      description: 'لفّ حيتك بزرار واحد، كل التفاح وكبّر، ومتخبطش في حد!',
      icon: Icons.turn_right,
      color: FunkyColors.mint,
      screen: SnakeArenaGame(),
      badge: 'جديد',
      arcade1234: true,
    ),
    GameModel(
      title: 'دبابات الشلة',
      description: 'المدفع بيلف لوحده.. دوس في اللحظة الصح وأصيب دبابات صحابك!',
      icon: Icons.gps_fixed,
      color: FunkyColors.orange,
      screen: TankBattleGame(),
      badge: 'جديد',
      arcade1234: true,
    ),
    GameModel(
      title: 'شد الحبل',
      description: 'دوس في اللحظة الصح لما المؤشر يبقى في النص واشدد الحبل لناحيتك!',
      icon: Icons.front_hand,
      color: FunkyColors.amber,
      screen: TugOfWarGame(),
      badge: 'جديد',
      arcade1234: true,
    ),
    GameModel(
      title: 'معركة التلج',
      description: 'ارمي كور التلج على أصحابك واجمع أكتر نقط قبل ما الوقت يخلص!',
      icon: Icons.ac_unit,
      color: FunkyColors.sky,
      screen: SnowBrawlGame(),
      badge: 'جديد',
      arcade1234: true,
    ),
    GameModel(
      title: 'اضرب الخلد',
      description: 'الخلد بيطلع وينزل بسرعة.. اضربه في مربعك قبل ما يهرب واجمع أكتر نقط!',
      icon: Icons.grid_on,
      color: FunkyColors.lime,
      screen: WhackMoleGame(),
      badge: 'جديد',
      arcade1234: true,
    ),
    GameModel(
      title: 'جري الفراخ',
      description: 'اقلب الجاذبية بدوسة واحدة وانط فوق الحفر! آخر فرخة واقفة تكسب',
      icon: Icons.flutter_dash,
      color: FunkyColors.amber,
      screen: ChickenRunGame(),
      badge: 'جديد',
      arcade1234: true,
    ),
    GameModel(
      title: 'سباق العربيات',
      description: 'حلبة من فوق وتلات لفات! لفّ بالأسهم اللي في ركنك وخلّي عربيتك على الأسفلت',
      icon: Icons.directions_car,
      color: FunkyColors.sky,
      screen: CarRaceGame(),
      badge: 'جديد',
      arcade1234: true,
    ),
    GameModel(
      title: 'أطعم الحمامة',
      description: 'مقلاع في ركنك وحمامة جعانة! دوس في الوقت الصح وأطعمها فتافيت العيش',
      icon: Icons.flutter_dash,
      color: FunkyColors.sky,
      screen: PigeonGame(),
      badge: 'جديد',
      arcade1234: true,
    ),
    GameModel(
      title: 'لمّ الفلوس',
      description: 'دراعك بيلف.. دوس في اللحظة الصح ولمّ أكتر فلوس قبل ما الكوم يخلص!',
      icon: Icons.monetization_on,
      color: FunkyColors.amber,
      screen: CoinGrabGame(),
      badge: 'جديد',
      arcade1234: true,
    ),
    GameModel(
      title: 'سومو الشلة',
      description: 'دوس بسرعة وادفع خصمك برا الحلبة قبل ما الوقت يخلص!',
      icon: Icons.sports_kabaddi,
      color: FunkyColors.coral,
      screen: SumoGame(),
      badge: 'جديد',
      arcade1234: true,
    ),
    GameModel(
      title: 'اقطفها',
      description: 'السمكة بتلف! دوس لما تعدي على لونك قبل غيرك',
      icon: Icons.catching_pokemon,
      color: FunkyColors.sky,
      screen: CatchGame(),
      badge: 'جديد',
      arcade1234: true,
    ),
    GameModel(
      title: 'سباق الدوس',
      description: 'دوس على حارتك أسرع من الكل في ٥ ثواني',
      icon: Icons.directions_run,
      color: FunkyColors.orange,
      screen: TapRaceGame(),
      badge: 'جديد',
      arcade1234: true,
    ),
    GameModel(
      title: 'كورة اللمسة',
      description: 'الم صاحب الكورة بس قبل ما تطير.. غلطة بتخصم',
      icon: Icons.sports_soccer,
      color: FunkyColors.violet,
      screen: TouchBallGame(),
      badge: 'جديد',
      arcade1234: true,
    ),
    GameModel(
      title: 'تحدّي الإيقاع',
      description: 'اسمع الإيقاع وقلّده تصفيق 👏 أو دوس 👆.. أدق توقيت يكسب',
      icon: Icons.music_note,
      color: FunkyColors.violet,
      screen: const RhythmGame(),
      badge: 'جديد',
      arcade1234: true,
    ),
    GameModel(
      title: 'لودو الشلة',
      description: 'لودو كلاسيك: طلّع أحجارك بـ٦، كُل اللي يقابلك، وأول واحد يدخل الأربعة البيت يكسب!',
      icon: Icons.casino,
      color: FunkyColors.lime,
      screen: const LudoGameScreen(),
      badge: 'جديد',
      arcade1234: true,
    ),
    GameModel(
      title: 'تمساح الشلة',
      description: 'دوس على ضرسة من ضروس التمساح.. واحدة فيهم موجوعة! اللي يقضمه يطلع خاسر وآخر واحد عايش يكسب 🐊',
      icon: Icons.cruelty_free,
      color: FunkyColors.mint,
      screen: const CrocGameScreen(),
      badge: 'جديد',
      arcade1234: true,
    ),
    GameModel(
      title: 'فلابي الشلة',
      description: 'دوس عشان الفرخة ترفع وتعدي من فتحات المواسير.. كل واحد رحلة واللي يعدي أكتر يكسب 🐤',
      icon: Icons.flutter_dash,
      color: FunkyColors.sky,
      screen: const FlappyGameScreen(),
      badge: 'جديد',
      arcade1234: true,
    ),
    GameModel(
      title: 'جولف الشلة',
      description: '٣ حفر ميني جولف بالتناوب.. اسحب من الكورة وصوّب، وأقل ضربات يكسب ⛳',
      icon: Icons.golf_course,
      color: FunkyColors.mint,
      screen: const MiniGolfGameScreen(),
      badge: 'جديد',
      arcade1234: true,
    ),
    GameModel(
      title: 'سباق العوائق',
      description: 'اجري واقفز فوق الحواجز! نفس المضمار للكل بالتناوب.. أسرع واحد يخلّص يكسب 🏃',
      icon: Icons.directions_run,
      color: FunkyColors.amber,
      screen: const ObstacleGameScreen(),
      badge: 'جديد',
      arcade1234: true,
    ),
    // كورة الشلة (SoccerGame) removed from the playable list by user request
    // (2026-11-26 00:45); code kept in games/offline/soccer_*.dart.
  ];
}
