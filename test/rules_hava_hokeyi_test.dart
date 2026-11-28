// Hava hokeyi kuralları (QA turu). Kaynak: USAA (United States Air-Table
// Hockey Association) kuralları — 7 sayıya oynanır, gol yiyen diski alır,
// disk bir yarıda 7 sn'den uzun tutulamaz, tokmak orta çizgiyi geçemez.
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_core/core/arcade.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:oyun_hava_hokeyi/src/hockey_engine.dart';
import 'package:oyun_hava_hokeyi/src/rules.dart';

void main() {
  final rules = AirHockeyRules();
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);
  HockeySim fresh([int n = 1]) => HockeySim(rules.build(planner.spec(n)).puzzle);

  test('gol atılınca disk gol yiyen tarafa verilir', () {
    final s = fresh()
      ..pause = 0
      ..bx = 500
      ..by = 300
      ..vx = 0
      ..vy = -30
      ..cx = 200;
    for (var i = 0; i < 30 && s.goalsScored == 0; i++) {
      s.tick(ArcadeInput.idle);
    }
    expect(s.goalsScored, 1);
    expect(s.by, lessThan(kMid), reason: 'rakip yarısında başlamalı');
  });

  test('7 sn kuralı: oyuncu yarısında oyalanan disk rakibe geçer', () {
    final s = fresh()
      ..pause = 0
      ..bx = 300
      ..by = 1000
      ..vx = 3
      ..vy = 0
      ..mx = 800
      ..my = kB - 80;
    var crossed = -1;
    for (var i = 0; i < 7 * 60 + 30; i++) {
      s.tick(const ArcadeInput(down: true, x: 800, y: kB));
      if (s.by < kMid) {
        crossed = i;
        break;
      }
    }
    expect(crossed, greaterThan(7 * 60 - 5), reason: '7 sn dolmadan verilmemeli');
    expect(crossed, lessThanOrEqualTo(7 * 60 + 5));
  });

  test('tokmaklar kendi yarısında kalır, disk masadan çıkmaz (rastgele 3000 tik)', () {
    final s = fresh(9);
    var t = 0;
    for (var i = 0; i < 3000 && !s.over; i++) {
      t = (t * 1103515245 + 12345) & 0x7fffffff;
      s.tick(ArcadeInput(down: true, x: (t % 1000).toDouble(), y: (600 + (t >> 10) % 1000).toDouble()));
      expect(s.my, greaterThanOrEqualTo(kMid + kMalletR - 0.01));
      expect(s.cy, lessThanOrEqualTo(kMid - kMalletR + 0.01));
      expect(s.bx, inInclusiveRange(kL + kPuckR - 0.01, kR - kPuckR + 0.01));
      expect(s.by, inInclusiveRange(kT - kPuckR * 1.5, kB + kPuckR * 1.5));
      expect(s.bx.isFinite && s.by.isFinite, isTrue);
    }
  });

  test('maç 7 gole (yüksek zorlukta) oynanır', () {
    for (var n = 1; n < 400; n++) {
      final s = fresh(n);
      if (s.matchMode && s.d >= 8) {
        expect(s.toWin, 7);
        return;
      }
    }
  });
}
