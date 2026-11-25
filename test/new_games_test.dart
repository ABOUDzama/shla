import 'package:flutter_test/flutter_test.dart';
import 'package:shella/data/taboo_data.dart';
import 'package:shella/data/emoji_guess_data.dart';
import 'package:shella/data/most_likely_data.dart';
import 'package:shella/games/offline/bus_complete_game.dart';
import 'package:shella/services/game_registry.dart';

void main() {
  group('Taboo data', () {
    test('every card has exactly 5 forbidden words', () {
      for (final c in tabooCards) {
        expect(c.forbidden.length, 5, reason: c.word);
      }
    });
    test('word is not among its forbidden words', () {
      for (final c in tabooCards) {
        expect(c.forbidden.contains(c.word), isFalse, reason: c.word);
      }
    });
    test('no duplicate card words', () {
      final words = tabooCards.map((c) => c.word).toList();
      expect(words.toSet().length, words.length);
    });
    test('has at least 60 cards', () {
      expect(tabooCards.length, greaterThanOrEqualTo(60));
    });
  });

  group('Emoji guess data', () {
    test('all fields non-empty', () {
      for (final c in emojiGuessCards) {
        expect(c.answer.trim().isNotEmpty, isTrue);
        expect(c.emojis.trim().isNotEmpty, isTrue);
        expect(c.category.trim().isNotEmpty, isTrue);
      }
    });
    test('has at least 60 cards', () {
      expect(emojiGuessCards.length, greaterThanOrEqualTo(60));
    });
    test('answer matching normalizes alef/taa forms', () {
      expect(
        BusCompleteGame.normalizeForCompare('قهوة الصبح'),
        BusCompleteGame.normalizeForCompare('قهوه الصبح'),
      );
      expect(
        BusCompleteGame.normalizeForCompare('  قهوة   الصبح '),
        BusCompleteGame.normalizeForCompare('قهوة الصبح'),
      );
    });
  });

  group('Most likely data', () {
    test('prompts are unique and non-empty', () {
      expect(mostLikelyPrompts.toSet().length, mostLikelyPrompts.length);
      for (final p in mostLikelyPrompts) {
        expect(p.trim().isNotEmpty, isTrue);
      }
    });
    test('has at least 50 prompts', () {
      expect(mostLikelyPrompts.length, greaterThanOrEqualTo(50));
    });
  });

  group('Registry', () {
    test('has 35 games and 11 new-badge games', () {
      expect(GameRegistry.games.length, 35);
      final newOnes =
          GameRegistry.games.where((g) => g.badge == 'جديد').toList();
      expect(newOnes.length, 11);
      expect(
          newOnes.map((g) => g.title),
          containsAll(<String>[
            'أسرع رد فعل',
            'كلمة السر',
            'الجاسوس',
            'أكمل المثل',
            'مين قالها؟',
            'أندر كافر',
            'مافيا',
            'لو خيروك',
            'أنا عمري ما',
            'كلمة بكلمة',
            'الشيفرة',
          ]));
    });
    test('game titles are unique', () {
      final titles = GameRegistry.games.map((g) => g.title).toList();
      expect(titles.toSet().length, titles.length);
    });
  });
}
