import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/ranking_challenge_game.dart';
import 'package:shella/games/offline/bus_complete_game.dart';
import 'package:shella/games/offline/proverb_game.dart';

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
}
