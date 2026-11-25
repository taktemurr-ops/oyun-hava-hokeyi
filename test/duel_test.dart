import 'package:flutter_test/flutter_test.dart';
import 'package:oyun_hava_hokeyi/src/hockey_engine.dart';
import 'package:oyun_hava_hokeyi/src/rules.dart';
import 'package:studio_core/core/arcade.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/net_sync.dart';

/// Çevrimiçi düello: durum yazımı, ayna görünüm, karşı oyuncunun girdisi ve
/// ev sahibi → misafir eşitlemesi (devralma dahil).
void main() {
  final rules = AirHockeyRules();
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);
  HockeyLevel level([int n = 5]) => rules.build(planner.spec(n)).puzzle;
  HockeySim duel([int n = 5]) => HockeySim(level(n))..enableDuel();

  /// Üst taraftaki oyuncu için bot girdisi (kendi ekranına göre).
  ArcadeInput rivalBot(HockeySim s) {
    final m = HockeySim(s.level)
      ..applyNetState(s.netState())
      ..mirrorView();
    return hockeyBot(m);
  }

  test('iki kişilik oyun: çevrimiçi masa açık', () {
    expect(rules.localPlayers, 2);
  });

  test('durum yazılıp okununca aynı durum', () {
    final s = duel();
    for (var i = 0; i < 400; i++) {
      s.rivalInput = rivalBot(s);
      s.tick(hockeyBot(s));
    }
    final wire = encodeNums(s.netState());
    final copy = duel()..applyNetState(decodeNums(wire));
    expect(encodeNums(copy.netState()), wire);
    expect(copy.ticks, s.ticks);
  });

  test('ayna görünüm iki kez uygulanınca aynı; skorlar yer değiştirir', () {
    final s = duel();
    s.myGoals = 2;
    s.cpuGoals = 1;
    s.bx = 300;
    s.by = 500;
    final before = encodeNums(s.netState());
    s.mirrorView();
    expect(s.myGoals, 1);
    expect(s.cpuGoals, 2);
    expect(s.bx, kWorldW - 300);
    expect(s.by, kWorldH - 500);
    s.mirrorView();
    expect(encodeNums(s.netState()), before);
  });

  test('karşı oyuncunun parmağı üst tokmağı ters masada sürer', () {
    final s = duel();
    for (var i = 0; i < 120; i++) {
      s.rivalInput = const ArcadeInput(down: true, x: 300, y: 1300);
      s.tick(const ArcadeInput(down: true, x: 500, y: 1400));
    }
    // ekranında (300, 1300) → masada (700, 300), tokmak parmağın biraz önünde
    expect(s.cx, closeTo(700, 1));
    expect(s.cy, closeTo(300 + kFingerOffset, 1));
  });

  test('rakip maçı alınca düello biter (alt taraf kaybeder)', () {
    final s = duel();
    s.cpuGoals = s.toWin - 1;
    s.pause = 0;
    s.bx = 500;
    s.by = kB - 60;
    s.vx = 0;
    s.vy = 30;
    s.mx = 200;
    for (var i = 0; i < 30 && !s.over; i++) {
      s.rivalInput = ArcadeInput.idle;
      s.tick(ArcadeInput.idle);
    }
    expect(s.over, isTrue);
    expect(s.duelWinner, 1);
  });

  test('ev sahibi yürütür, misafir anlık durumlardan izler; ev sahibi düşünce misafir devralır', () {
    final host = duel(), shown = duel(), guestSim = duel();
    final toGuest = <(int, String)>[];
    var now = 0;
    final hostSync = NetSync(mySeat: 0, seats: 2, humans: {0, 1}, send: (d) => toGuest.add((0, d)));
    final gs = NetSync(mySeat: 1, seats: 2, humans: {0, 1}, send: (d) => hostSync.receive(1, d, now));
    expect(hostSync.isHost, isTrue);
    var hostUp = true;
    var tookOver = false;
    for (var frame = 0; frame < 60 * 60 * 6 && host.duelWinner < 0 && guestSim.duelWinner < 0; frame++) {
      now = frame * 1000 ~/ 60;
      // misafir: parmağıyla kendi ekranında topa doğru gider
      gs.setAxes([1, 500, 1300, 0, 0]);
      gs.pump(now);
      if (hostUp) {
        final a = hostSync.axesOf(1);
        host.rivalInput = a == null ? null : ArcadeInput(down: a[0] > 0.5, x: a[1], y: a[2]);
        host.tick(hockeyBot(host));
        hostSync.publish((host.ticks * 1000 / 60).round(), encodeNums(host.netState()), now);
        if (frame == 60 * 2) hostUp = false; // 2 sn sonra ev sahibi düşer
      }
      for (final m in toGuest) {
        gs.receive(m.$1, m.$2, now);
      }
      toGuest.clear();
      if (!tookOver && gs.checkTakeover(now)) {
        tookOver = true;
        guestSim.applyNetState(decodeNums(gs.latest!.payload));
        expect(guestSim.ticks, greaterThan(60));
      }
      if (tookOver) {
        guestSim.rivalInput = const ArcadeInput(down: true, x: 500, y: 1300);
        guestSim.tick(hockeyBot(guestSim));
      } else {
        final fr = gs.frame(now);
        if (fr != null) {
          shown
            ..applyNetState(guestSim.lerpNet(decodeNums(fr.$1.payload), decodeNums(fr.$2.payload), fr.$3))
            ..mirrorView();
          // misafirin ekranında kendi tokmağı hep alt yarıda
          expect(shown.my, greaterThanOrEqualTo(kMid));
        }
      }
    }
    expect(tookOver, isTrue);
    expect(gs.isHost, isTrue);
    expect(gs.ep, 1);
    // devralan misafir maçı sonuna kadar oynar
    expect(guestSim.duelWinner, isNot(-1));
  });
}
