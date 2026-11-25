import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/soccer_logic.dart';

void main() {
  soccerBotProof();
  test('kickoff: ball at center, teams on own halves, 0-0', () {
    final m = SoccerMatch(teamSizes: [2, 2], random: Random(1));
    expect(m.players.length, 4);
    expect(m.ballX, 0.5);
    expect(m.ballY, SoccerMatch.fieldH / 2);
    expect(m.scores, [0, 0]);
    expect(m.players.where((p) => p.team == 0).every((p) => p.y > SoccerMatch.fieldH / 2), isTrue);
    expect(m.players.where((p) => p.team == 1).every((p) => p.y < SoccerMatch.fieldH / 2), isTrue);
  });

  test('1v1 and 2v1 sizes build the right number of players', () {
    expect(SoccerMatch(teamSizes: [1, 1]).players.length, 2);
    expect(SoccerMatch(teamSizes: [2, 1]).players.length, 3);
  });

  test('player running into the ball moves it away', () {
    final m = SoccerMatch(teamSizes: [1, 1], random: Random(1));
    final p = m.players[0];
    p.x = 0.5;
    p.y = SoccerMatch.fieldH / 2 + 0.12;
    p.heading = -pi / 2;
    m.ballX = 0.5;
    m.ballY = SoccerMatch.fieldH / 2;
    for (var i = 0; i < 6; i++) {
      m.step(1 / 30, {});
    }
    expect(m.ballVy, lessThan(0));
    expect(m.ballY, lessThan(SoccerMatch.fieldH / 2 - 0.02));
  });

  test('ball into the top mouth scores for team 0 and resets after the pause', () {
    final m = SoccerMatch(teamSizes: [1, 1], random: Random(1));
    // keep both players far from the ball
    m.players[0].x = 0.1;
    m.players[1].x = 0.9;
    m.ballX = 0.5 + 0.12;
    m.ballY = 0.2;
    m.ballVx = 0;
    m.ballVy = -1.2;
    for (var i = 0; i < 40 && m.scores[0] == 0; i++) {
      m.step(1 / 30, {});
    }
    expect(m.scores, [1, 0]);
    expect(m.lastScorer, 0);
    var guard = 0;
    while (m.goalPause > 0 && guard++ < 100) {
      m.step(1 / 30, {});
    }
    expect(m.lastScorer, isNull);
    expect(m.ballX, 0.5);
    expect(m.ballY, SoccerMatch.fieldH / 2);
    expect(m.scores, [1, 0]);
  });

  test('ball outside the goal mouth bounces and does not score', () {
    final m = SoccerMatch(teamSizes: [1, 1], random: Random(1));
    m.ballX = 0.15;
    m.ballY = 0.05;
    m.ballVy = -1.0;
    m.step(1 / 30, {});
    expect(m.scores, [0, 0]);
    expect(m.ballVy, greaterThan(0));
  });

  test('first to 3 ends the match with a winner', () {
    final m = SoccerMatch(teamSizes: [1, 1]);
    m.scores[1] = 3;
    expect(m.over, isTrue);
    expect(m.winner, 1);
  });

  test('timer end: equal scores are a draw, more goals wins', () {
    final m = SoccerMatch(teamSizes: [1, 1]);
    m.timeLeft = 0;
    expect(m.over, isTrue);
    expect(m.winner, isNull);
    m.scores[0] = 2;
    m.scores[1] = 1;
    expect(m.winner, 0);
  });

  test('turning input changes heading; steering is clamped inside pitch', () {
    final m = SoccerMatch(teamSizes: [1, 1]);
    final h0 = m.players[0].heading;
    m.step(0.1, {0: 1});
    expect(m.players[0].heading, greaterThan(h0));
    m.players[0].heading = 0;
    for (var i = 0; i < 300; i++) {
      m.step(1 / 30, {});
    }
    expect(m.players[0].x, lessThanOrEqualTo(1 - SoccerMatch.playerR + 1e-9));
  });

  test('bots steer toward the ball', () {
    final m = SoccerMatch(teamSizes: [1, 1], random: Random(3));
    m.botIndexes.add(1);
    final p = m.players[1];
    p.x = 0.2;
    p.y = 0.4;
    p.heading = 0;
    m.ballX = 0.2;
    m.ballY = 1.0;
    m.step(0.2, {});
    expect(p.heading, greaterThan(0));
  });
}

// Added: all-bot play proof (no kick button; running into the ball scores).
void soccerBotProof() {
  test('bots-only 2v2 matches produce goals and finish', () {
    var total = 0, finished = 0, withGoal = 0;
    for (var seed = 0; seed < 30; seed++) {
      final m = SoccerMatch(teamSizes: const [2, 2], random: Random(seed));
      m.botIndexes.addAll({0, 1, 2, 3});
      var t = 0.0;
      while (!m.over && t < 200) {
        m.step(0.033, const {});
        t += 0.033;
      }
      if (m.over) finished++;
      final g = m.scores[0] + m.scores[1];
      total += g;
      if (g > 0) withGoal++;
    }
    // ignore: avoid_print
    print('SOCCER_PROOF finished=$finished/30 matchesWithGoal=$withGoal/30 totalGoals=$total');
    expect(finished, 30);
    expect(withGoal, greaterThan(10));
  });
}
