import 'package:flutter_test/flutter_test.dart';
import 'package:studio_core/core/arcade.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:oyun_hava_hokeyi/src/hockey_engine.dart';
import 'package:oyun_hava_hokeyi/src/rules.dart';

void main() {
  final rules = AirHockeyRules();
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);

  HockeySim fresh([int n = 1]) => HockeySim(rules.build(planner.spec(n)).puzzle);

  test('a shot into the rival slot is a goal', () {
    final s = fresh();
    s.pause = 0;
    s.bx = 500;
    s.by = 300;
    s.vx = 0;
    s.vy = -30;
    s.cx = 200;
    s.cy = 400;
    final before = s.goalsScored;
    for (var i = 0; i < 30 && s.goalsScored == before; i++) {
      s.tick(const ArcadeInput(down: true, x: 500, y: 1400));
    }
    expect(s.goalsScored, before + 1);
  });

  test('the puck bounces off the rails beside the goal', () {
    final s = fresh();
    s.pause = 0;
    s.bx = 200;
    s.by = 300;
    s.vx = 0;
    s.vy = -20;
    s.cx = 800;
    s.cy = 600;
    for (var i = 0; i < 20; i++) {
      s.tick(const ArcadeInput(down: true, x: 500, y: 1400));
    }
    expect(s.goalsScored, 0);
    expect(s.vy, greaterThan(0));
  });

  test('goal guard booster blocks your own goal', () {
    final s = fresh();
    expect(s.useBooster(), isTrue);
    s.pause = 0;
    s.bx = 500;
    s.by = 1300;
    s.vx = 0;
    s.vy = 30;
    s.mx = 200;
    s.my = 1000;
    for (var i = 0; i < 20; i++) {
      s.tick(const ArcadeInput(down: true, x: 200, y: 1070));
    }
    expect(s.goalsConceded, 0);
  });

  test('a still puck in your half is handed to the rival', () {
    final s = fresh();
    for (var i = 0; i < 260; i++) {
      s.tick(const ArcadeInput(down: true, x: 150, y: 1500));
    }
    expect(s.by < kMid || s.goalsConceded > 0 || s.cpuGoals > 0, isTrue);
  });

  test('autopilot wins the first matches and late levels', () {
    for (final n in [1, 2, 3, 4, 5, 6, 30, 200, 5000]) {
      final s = fresh(n);
      expect(runBot(s, rules.bot, 60 * 60 * 6).won, isTrue, reason: 'level $n');
    }
  });
}
