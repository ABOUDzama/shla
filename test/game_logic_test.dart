import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/ranking_challenge_game.dart';
import 'package:shella/games/offline/bus_complete_game.dart';
import 'package:shella/games/offline/proverb_game.dart';
import 'package:shella/games/offline/undercover_game.dart';
import 'package:shella/games/offline/mafia_game.dart';
import 'package:shella/games/offline/would_rather_game.dart';
import 'package:shella/games/offline/never_have_i_game.dart';

void main() {
  group('RankingChallengeGame.scoreGuess', () {
    const truth = ['أ', 'ب', 'ج', 'د'];

    test('perfect order scores 3 per item', () {
      expect(RankingChallengeGame.scoreGuess(const ['أ', 'ب', 'ج', 'د'], truth), 12);
    });

    test('exact position 3, off-by-one 1, further away 0', () {
      // أ exact(3), ج off-by-one(1), ب off-by-one(1), د exact(3) = 8
      expect(RankingChallengeGame.scoreGuess(const ['أ', 'ج', 'ب', 'د'], truth), 8);
      // fully reversed: only the two middle items are off-by-one = 2
      expect(RankingChallengeGame.scoreGuess(const ['د', 'ج', 'ب', 'أ'], truth), 2);
    });

    test('unknown items score nothing', () {
      expect(RankingChallengeGame.scoreGuess(const ['س', 'ص', 'ع', 'ف'], truth), 0);
    });

    test('winner is the higher total score', () {
      final p1 = RankingChallengeGame.scoreGuess(const ['أ', 'ب', 'ج', 'د'], truth);
      final p2 = RankingChallengeGame.scoreGuess(const ['د', 'ج', 'ب', 'أ'], truth);
      expect(p1 > p2, isTrue);
    });
  });

  group('BusCompleteGame.normalize', () {
    test('alef variants unify', () {
      expect(BusCompleteGame.normalize('أحمد'), BusCompleteGame.normalize('احمد'));
      expect(BusCompleteGame.normalize('إسراء'), BusCompleteGame.normalize('اسراء'));
      expect(BusCompleteGame.normalize('آية'), BusCompleteGame.normalize('ايه'));
    });

    test('taa marbuta and alef maqsura unify', () {
      expect(BusCompleteGame.normalize('مدرسة'), BusCompleteGame.normalize('مدرسه'));
      expect(BusCompleteGame.normalize('فتى'), BusCompleteGame.normalize('فتي'));
    });

    test('tashkeel and tatweel stripped', () {
      expect(BusCompleteGame.normalize('أَحْمَد'), 'احمد');
      expect(BusCompleteGame.normalize('احــمد'), 'احمد');
    });
  });

  group('BusCompleteGame.startsWithLetter', () {
    test('normalized first-letter check', () {
      expect(BusCompleteGame.startsWithLetter('بيت', 'ب'), isTrue);
      expect(BusCompleteGame.startsWithLetter('بَيت', 'ب'), isTrue);
      expect(BusCompleteGame.startsWithLetter('أحمد', 'ا'), isTrue);
      expect(BusCompleteGame.startsWithLetter('سمير', 'ب'), isFalse);
    });
  });

  group('BusCompleteGame.scoreRound', () {
    final players = ['علي', 'منى'];
    final cats = ['ولد', 'بلاد'];

    test('unique valid=10, shared valid=5, wrong letter or empty=0', () {
      final scores = BusCompleteGame.scoreRound(players, cats, 'ب', {
        'علي': {'ولد': 'باسم', 'بلاد': 'البحرين'},
        'منى': {'ولد': 'باسم', 'بلاد': 'السودان'},
      });
      // باسم shared -> 5 each; البحرين unique -> 10; السودان wrong letter -> 0
      expect(scores['علي'], 15);
      expect(scores['منى'], 5);
    });

    test('alef-variant duplicates count as the same answer', () {
      final scores = BusCompleteGame.scoreRound(players, const ['ولد'], 'ا', {
        'علي': {'ولد': 'احمد'},
        'منى': {'ولد': 'أحمد'},
      });
      expect(scores['علي'], 5);
      expect(scores['منى'], 5);
    });

    test('different answers both score unique', () {
      final scores = BusCompleteGame.scoreRound(players, const ['ولد'], 'م', {
        'علي': {'ولد': 'محمد'},
        'منى': {'ولد': 'مصطفى'},
      });
      expect(scores['علي'], 10);
      expect(scores['منى'], 10);
    });

    test('empty answer scores zero', () {
      final scores = BusCompleteGame.scoreRound(players, const ['ولد'], 'ك', {
        'علي': {'ولد': ''},
        'منى': {'ولد': 'كريم'},
      });
      expect(scores['علي'], 0);
      expect(scores['منى'], 10);
    });
  });

  group('ProverbGame.buildOptions', () {
    test('4 options: correct ending plus 3 unique others', () {
      for (var i = 0; i < ProverbGame.proverbs.length; i++) {
        final options = ProverbGame.buildOptions(ProverbGame.proverbs, i, 42);
        expect(options.length, 4);
        expect(options, contains(ProverbGame.proverbs[i].end));
        expect(options.toSet().length, 4, reason: 'duplicate options at $i');
      }
    });
    test('deterministic for the same seed', () {
      final a = ProverbGame.buildOptions(ProverbGame.proverbs, 3, 7);
      final b = ProverbGame.buildOptions(ProverbGame.proverbs, 3, 7);
      expect(a, b);
    });
    test('proverb data: unique starts and endings', () {
      final starts = ProverbGame.proverbs.map((p) => p.start).toList();
      final ends = ProverbGame.proverbs.map((p) => p.end).toList();
      expect(starts.toSet().length, starts.length);
      expect(ends.toSet().length, ends.length);
    });
  });

  group('UndercoverGame rules (grounded in official Undercover rules)', () {
    test('rolesFor: 4-5 players get exactly 1 undercover, no mr white', () {
      for (final n in [4, 5]) {
        final roles = UndercoverGame.rolesFor(n, Random(7));
        expect(roles.length, n);
        expect(roles.where((r) => r == UndercoverGame.undercover).length, 1);
        expect(roles.where((r) => r == UndercoverGame.mrWhite).length, 0);
      }
    });
    test('rolesFor: 6-8 players get 1 undercover + 1 mr white; 9+ get 2+1', () {
      for (final n in [6, 7, 8]) {
        final roles = UndercoverGame.rolesFor(n, Random(7));
        expect(roles.where((r) => r == UndercoverGame.undercover).length, 1);
        expect(roles.where((r) => r == UndercoverGame.mrWhite).length, 1);
      }
      final roles9 = UndercoverGame.rolesFor(9, Random(7));
      expect(roles9.where((r) => r == UndercoverGame.undercover).length, 2);
      expect(roles9.where((r) => r == UndercoverGame.mrWhite).length, 1);
    });
    test('winner: civilians win when all infiltrators ousted', () {
      final roles = {'a': 'civilian', 'b': 'civilian', 'c': 'undercover'};
      expect(UndercoverGame.winner(roles, {'c'}), 'civilians');
      // Ousting a civilian leaves 1 civilian vs 1 undercover: infiltrators win.
      expect(UndercoverGame.winner(roles, {'a'}), 'infiltrators');
    });
    test('winner: infiltrators win when only 1 civilian remains', () {
      final roles = {
        'a': 'civilian', 'b': 'civilian', 'c': 'civilian',
        'd': 'undercover', 'e': 'mrwhite',
      };
      expect(UndercoverGame.winner(roles, {'a', 'b'}), 'infiltrators');
    });
    test('scoreWin: civilians +2, undercover +10, mr white +6, crack +6', () {
      final roles = {
        'a': 'civilian', 'b': 'civilian',
        'c': 'undercover', 'd': 'mrwhite',
      };
      final civ = UndercoverGame.scoreWin({}, roles, winnerSide: 'civilians');
      expect(civ, {'a': 2, 'b': 2});
      final infil =
          UndercoverGame.scoreWin({}, roles, winnerSide: 'infiltrators');
      expect(infil, {'c': 10, 'd': 6});
      final crack = UndercoverGame.scoreWin({}, roles,
          winnerSide: 'mrwhite', mrWhiteCracker: 'd');
      expect(crack, {'d': 6});
    });
    test('normalizeGuess: conservative Arabic normalization', () {
      expect(UndercoverGame.normalizeGuess('مدرسة'), 'مدرسه');
      expect(UndercoverGame.normalizeGuess('مدرسه'), 'مدرسه');
      expect(UndercoverGame.normalizeGuess('  قهوة  '), 'قهوه');
      expect(UndercoverGame.normalizeGuess('أحمد'), 'احمد');
      expect(UndercoverGame.normalizeGuess('إبراهيم'), 'ابراهيم');
      expect(UndercoverGame.normalizeGuess('على'), 'علي');
      expect(UndercoverGame.normalizeGuess('كـشـري'), 'كشري');
      expect(UndercoverGame.normalizeGuess('مُدَرِّسَة'), 'مدرّسه'.replaceAll('ّ',''));
      // Wrong guess stays wrong.
      expect(
          UndercoverGame.normalizeGuess('شاي') ==
              UndercoverGame.normalizeGuess('قهوة'),
          isFalse);
    });
    test('wordPairs: 18 pairs, distinct words within and across pairs', () {
      expect(UndercoverGame.wordPairs.length, 18);
      final all = UndercoverGame.wordPairs.expand((p) => p).toList();
      expect(all.toSet().length, all.length);
      for (final p in UndercoverGame.wordPairs) {
        expect(p[0] == p[1], isFalse);
      }
    });
  });

  group('MafiaGame rules (grounded in classic Mafia, Wikipedia)', () {
    test('rolesFor: about a third mafia (Davidoff), min 1', () {
      final r5 = MafiaGame.rolesFor(5, Random(3));
      expect(r5.length, 5);
      expect(r5.where((r) => r == MafiaGame.mafia).length, 2);
      // Doctor and detective enter from 6 players (house rule, labeled).
      expect(r5.contains(MafiaGame.doctor), isFalse);
      expect(r5.contains(MafiaGame.detective), isFalse);
      final r9 = MafiaGame.rolesFor(9, Random(3));
      expect(r9.length, 9);
      expect(r9.where((r) => r == MafiaGame.mafia).length, 3);
      expect(r9.where((r) => r == MafiaGame.doctor).length, 1);
      expect(r9.where((r) => r == MafiaGame.detective).length, 1);
      expect(r9.where((r) => r == MafiaGame.villager).length, 4);
    });
    test('winner: village wins when no mafia remains', () {
      final roles = {'a': 'mafia', 'b': 'villager', 'c': 'villager'};
      expect(MafiaGame.winner(roles, {'b', 'c'}), 'village');
    });
    test('winner: mafia wins on numerical parity', () {
      final roles = {'a': 'mafia', 'b': 'villager', 'c': 'villager', 'd': 'villager'};
      expect(MafiaGame.winner(roles, {'a', 'b', 'c', 'd'}), isNull);
      expect(MafiaGame.winner(roles, {'a', 'b', 'c'}), isNull);
      // Parity: mafia equal the village.
      expect(MafiaGame.winner(roles, {'a', 'b'}), 'mafia');
    });
    test('breakTie: seeded and deterministic', () {
      final tied = ['a', 'b', 'c'];
      final pick1 = MafiaGame.breakTie(tied, Random(42));
      final pick2 = MafiaGame.breakTie(tied, Random(42));
      expect(tied.contains(pick1), isTrue);
      expect(pick1, pick2);
    });
    test('scoreWin: winning team members +3 each', () {
      final roles = {'a': 'mafia', 'b': 'villager', 'c': 'doctor'};
      final mafiaWin =
          MafiaGame.scoreWin({'a': 1, 'b': 0, 'c': 0}, roles, winnerSide: 'mafia');
      expect(mafiaWin, {'a': 4, 'b': 0, 'c': 0});
      final villageWin =
          MafiaGame.scoreWin({}, roles, winnerSide: 'village');
      expect(villageWin, {'b': 3, 'c': 3});
    });
  });
  group('WouldRatherGame content and tally', () {
    test('questions: 24 pairs, non-empty, a != b, all unique', () {
      expect(WouldRatherGame.questions.length, 24);
      final seen = <String>{};
      for (final q in WouldRatherGame.questions) {
        expect(q.a.trim().isNotEmpty, isTrue);
        expect(q.b.trim().isNotEmpty, isTrue);
        expect(q.a, isNot(q.b));
        expect(seen.add('${q.a}|${q.b}'), isTrue);
      }
    });
    test('tally: splits voters by pick, preserves names', () {
      final (a, b) = WouldRatherGame.tally({'x': 0, 'y': 1, 'z': 0});
      expect(a, ['x', 'z']);
      expect(b, ['y']);
      final (a2, b2) = WouldRatherGame.tally({});
      expect(a2, isEmpty);
      expect(b2, isEmpty);
    });
  });

  group('NeverHaveIGame content and order', () {
    test('statements: 24, non-empty, unique, family-friendly (no drinking/adult refs)',
        () {
      expect(NeverHaveIGame.statements.length, 24);
      final seen = <String>{};
      for (final st in NeverHaveIGame.statements) {
        expect(st.trim().isNotEmpty, isTrue);
        expect(seen.add(st), isTrue);
        expect(st.startsWith('أنا عمري ما'), isTrue);
        // Content guard: keep the game gathering/family-safe. Whole-word
        // match so 'كبيرة' doesn't trip the 'بيرة' check.
        for (final banned in ['خمر', 'شراب', 'سكر', 'بيرة', 'كحول']) {
          final re = RegExp(
              '(^|[^\\u0621-\\u064A])\$banned([^\\u0621-\\u064A]|\$)');
          expect(re.hasMatch(st), isFalse, reason: st);
        }
      }
    });
    test('shuffledOrder: permutation, no repeats, deterministic per seed', () {
      final o1 = NeverHaveIGame.shuffledOrder(Random(1));
      final o2 = NeverHaveIGame.shuffledOrder(Random(1));
      final o3 = NeverHaveIGame.shuffledOrder(Random(2));
      expect(o1.length, NeverHaveIGame.statements.length);
      expect(o1.toSet().length, o1.length); // no repeats
      expect(List.from(o1)..sort(),
          List.generate(NeverHaveIGame.statements.length, (i) => i));
      expect(o1, o2); // same seed, same order
      expect(o1, isNot(o3));
    });
  });
}
