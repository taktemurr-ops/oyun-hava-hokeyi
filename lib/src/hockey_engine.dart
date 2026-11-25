import 'dart:math' as math;

import 'package:studio_core/core/arcade.dart';
import 'package:studio_core/core/arcade_duel.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/rng.dart';

/// Air hockey seen from above: the player's mallet in the bottom half, the
/// rival's in the top half. The puck slides with little friction and bounces
/// off the rails; a goal is scored when it enters the slot in a short end.
class HockeyLevel {
  final ArcadeMeta meta;
  final int difficulty;
  final int theme;
  const HockeyLevel(this.meta, this.difficulty, this.theme);
}

HockeyLevel generateHockey(LevelSpec spec) =>
    HockeyLevel(ArcadeMeta.of(spec), spec.difficulty.clamp(1, 10), spec.theme % 4);

const double kL = 120, kR = 880, kT = 160, kB = 1440, kMid = 800;
const double kGoalHalf = 170, kPuckR = 30, kMalletR = 56;
const double _friction = 0.996, _vMax = 36, _restitution = 0.92;

/// Finger offset: the mallet sits a little above the finger so it stays visible.
const double kFingerOffset = 70;

class HockeySim extends ArcadeSim implements DuelSim {
  final HockeyLevel level;
  // puck
  double bx = 500, by = kMid + 170, vx = 0, vy = 0;
  // mallets (m = player, c = rival) and their last-tick velocity
  double mx = 500, my = kB - 150, mvx = 0, mvy = 0;
  double cx = 500, cy = kT + 130, cvx = 0, cvy = 0;
  int pause = 0, idle = 0, cool = 0, guard = 0;
  // match
  int myGoals = 0, cpuGoals = 0, toWin = 3;
  int goalsScored = 0, goalsConceded = 0, matchesWon = 0, saves = 0, bestStreak = 0, streak = 0;
  int lastEvent = 0; // 1 hit, 2 goal for, 3 goal against, 4 rail
  String flash = '';
  int flashTicks = 0;

  /// Çevrimiçi düello: üst tokmağı karşıdaki oyuncu sürer (null: yapay zekâ).
  ArcadeInput? _rival;
  bool duel = false;

  HockeySim(this.level) : super(level.meta, lives: 3) {
    _setupMatch();
  }

  int get d => level.difficulty;
  bool get matchMode => meta.goal;

  void _setupMatch() {
    myGoals = 0;
    cpuGoals = 0;
    toWin = d <= 3 ? 3 : (d <= 7 ? 5 : 7);
    mx = 500;
    my = kB - 150;
    cx = 500;
    cy = kT + 130;
    _faceOff(0);
  }

  /// Puck placed still in the half of [side] (0 player, 1 rival).
  void _faceOff(int side) {
    bx = 500;
    by = kMid + (side == 0 ? 170 : -170);
    vx = 0;
    vy = 0;
    pause = 40;
    idle = 0;
    cool = 0;
  }

  double _rnd(int k) => SeededRandom(mixSeed([meta.seed, ticks, k, 61])).nextDouble();

  void _say(String s) {
    flash = s;
    flashTicks = 60;
  }

  @override
  void update(ArcadeInput input) {
    lastEvent = 0;
    if (flashTicks > 0) flashTicks--;
    if (guard > 0) guard--;
    _movePlayer(input);
    final rival = _rival;
    if (rival != null) {
      _moveRival(rival);
    } else {
      _moveCpu();
    }
    if (pause > 0) {
      pause--;
      return;
    }
    _step();
  }

  void _movePlayer(ArcadeInput i) {
    var tx = mx, ty = my;
    if (i.down && i.hasPointer) {
      tx = i.x;
      ty = i.y - kFingerOffset;
    }
    if (i.dirX != 0) tx = mx + i.dirX * 40;
    if (i.dirY != 0) ty = my + i.dirY * 40;
    tx = clampD(tx, kL + kMalletR, kR - kMalletR);
    ty = clampD(ty, kMid + kMalletR, kB - kMalletR);
    final nx = moveToward(mx, tx, 42), ny = moveToward(my, ty, 42);
    mvx = nx - mx;
    mvy = ny - my;
    mx = nx;
    my = ny;
  }

  /// Karşıdaki oyuncunun tokmağı: oyuncununkiyle aynı kurallar, masa ters.
  void _moveRival(ArcadeInput raw) {
    final i = mirrorInput(raw);
    var tx = cx, ty = cy;
    if (i.down && i.hasPointer) {
      tx = i.x;
      ty = i.y + kFingerOffset;
    }
    if (i.dirX != 0) tx = cx + i.dirX * 40;
    if (i.dirY != 0) ty = cy + i.dirY * 40;
    tx = clampD(tx, kL + kMalletR, kR - kMalletR);
    ty = clampD(ty, kT + kMalletR, kMid - kMalletR);
    final nx = moveToward(cx, tx, 42), ny = moveToward(cy, ty, 42);
    cvx = nx - cx;
    cvy = ny - cy;
    cx = nx;
    cy = ny;
  }

  void _moveCpu() {
    var sp = 9.0 + d * 1.3;
    if (cool > 0) cool--;
    double tx, ty;
    final fast = math.sqrt(vx * vx + vy * vy) >= 10 + d * 1.6 && vy <= 0;
    if (by < kMid - 30 && pause == 0 && cool == 0 && !fast) {
      // attack: get behind the puck and drive it toward the bottom goal,
      // aiming away from the player's mallet
      final aim = 500.0 + (mx > 500 ? -1 : 1) * (40 + d * 9) + (_rnd(1) - 0.5) * (160 - d * 10);
      var ux = aim - bx, uy = (kB + 40) - by;
      final n = math.sqrt(ux * ux + uy * uy);
      ux /= n;
      uy /= n;
      const reach = kPuckR + kMalletR + 12;
      final bxp = bx - ux * reach, byp = by - uy * reach;
      if (by < kT + kPuckR + kMalletR + 6) {
        // pinned against the top rail: sweep it toward the middle
        tx = bx + (bx < 500 ? 40 : -40);
        ty = by - 10;
      } else if (cy < by - 10 && _dist(cx, cy, bxp, byp) < 30) {
        tx = bx + ux * 60;
        ty = by + uy * 60;
      } else if (cy > by - 10) {
        // go around the puck without touching it
        final side = cx < bx ? -1 : 1;
        tx = bx + side * (kPuckR + kMalletR + 20);
        ty = by - kPuckR - kMalletR - 30;
      } else {
        tx = bxp;
        ty = byp;
      }
    } else {
      // defend: stay between the puck and the goal
      sp = 3.0 + d * 0.75;
      tx = 500 + (bx - 500) * 0.45;
      ty = kT + 110;
    }
    tx = clampD(tx, kL + kMalletR, kR - kMalletR);
    ty = clampD(ty, kT + kMalletR, kMid - kMalletR);
    final nx = moveToward(cx, tx, sp), ny = moveToward(cy, ty, sp);
    cvx = nx - cx;
    cvy = ny - cy;
    cx = nx;
    cy = ny;
  }

  // ---- DuelSim ----

  @override
  set rivalInput(ArcadeInput? input) => _rival = input;

  @override
  void enableDuel() {
    duel = true;
    lives = 1;
  }

  @override
  int get duelWinner => won ? 0 : (dead ? 1 : -1);

  @override
  List<double> netState() => [
        ticks.toDouble(), bx, by, vx, vy, mx, my, mvx, mvy, cx, cy, cvx, cvy, //
        pause.toDouble(), idle.toDouble(), cool.toDouble(), guard.toDouble(),
        myGoals.toDouble(), cpuGoals.toDouble(), toWin.toDouble(),
        flashCode(flash, _flashes).toDouble(), flashTicks.toDouble(), lastEvent.toDouble(), score.toDouble(),
        won ? 1.0 : 0.0, dead ? 1.0 : 0.0,
      ];

  @override
  void applyNetState(List<double> s) {
    if (s.length < 26) return;
    int n(int i) => s[i].round();
    ticks = n(0);
    bx = s[1];
    by = s[2];
    vx = s[3];
    vy = s[4];
    mx = s[5];
    my = s[6];
    mvx = s[7];
    mvy = s[8];
    cx = s[9];
    cy = s[10];
    cvx = s[11];
    cvy = s[12];
    pause = n(13);
    idle = n(14);
    cool = n(15);
    guard = n(16);
    myGoals = n(17);
    cpuGoals = n(18);
    toWin = n(19);
    flash = _flashes[n(20).clamp(0, _flashes.length - 1)];
    flashTicks = n(21);
    lastEvent = n(22);
    score = n(23);
    if (s[24] > 0.5 && !won) win();
    if (s[25] > 0.5 && !dead) {
      lives = 1;
      shield = 0;
      hit();
    }
  }

  @override
  List<double> lerpNet(List<double> a, List<double> b, double f) => lerpAt(a, b, f, const [1, 2, 5, 6, 9, 10]);

  @override
  void mirrorView() {
    bx = kWorldW - bx;
    by = kWorldH - by;
    vx = -vx;
    vy = -vy;
    final ox = mx, oy = my, ovx = mvx, ovy = mvy;
    mx = kWorldW - cx;
    my = kWorldH - cy;
    mvx = -cvx;
    mvy = -cvy;
    cx = kWorldW - ox;
    cy = kWorldH - oy;
    cvx = -ovx;
    cvy = -ovy;
    final g = myGoals;
    myGoals = cpuGoals;
    cpuGoals = g;
    if (lastEvent == 2) {
      lastEvent = 3;
    } else if (lastEvent == 3) {
      lastEvent = 2;
    }
    if (flash == 'GOAL!') {
      flash = 'GOAL ×';
    } else if (flash == 'GOAL ×') {
      flash = 'GOAL!';
    }
  }

  static double _dist(double ax, double ay, double bx, double by) {
    final dx = ax - bx, dy = ay - by;
    return math.sqrt(dx * dx + dy * dy);
  }

  bool _collide(double px, double py, double pvx, double pvy) {
    final dx = bx - px, dy = by - py;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist >= kPuckR + kMalletR || dist == 0) return false;
    final nx = dx / dist, ny = dy / dist;
    bx = px + nx * (kPuckR + kMalletR);
    by = py + ny * (kPuckR + kMalletR);
    final rvx = vx - pvx, rvy = vy - pvy;
    final dot = rvx * nx + rvy * ny;
    if (dot < 0) {
      vx -= (1 + _restitution) * dot * nx;
      vy -= (1 + _restitution) * dot * ny;
    }
    final sp = math.sqrt(vx * vx + vy * vy);
    if (sp > _vMax) {
      vx *= _vMax / sp;
      vy *= _vMax / sp;
    }
    return true;
  }

  void _step() {
    const steps = 3;
    for (var k = 0; k < steps; k++) {
      bx += vx / steps;
      by += vy / steps;
      if (_collide(mx, my, mvx, mvy)) {
        if (lastEvent == 0) lastEvent = 1;
        if (by > kMid + 300 && vy < 0) saves++;
      }
      if (_collide(cx, cy, cvx, cvy)) {
        if (lastEvent == 0) lastEvent = 1;
        if (cool == 0) cool = 44 - 3 * d;
      }
      if (bx < kL + kPuckR) {
        bx = kL + kPuckR;
        vx = vx.abs() * 0.9;
        lastEvent = 4;
      }
      if (bx > kR - kPuckR) {
        bx = kR - kPuckR;
        vx = -vx.abs() * 0.9;
        lastEvent = 4;
      }
      final inGoal = (bx - 500).abs() < kGoalHalf - kPuckR * 0.3;
      if (by < kT + kPuckR) {
        if (inGoal) {
          if (by < kT - kPuckR) {
            _point(true);
            return;
          }
        } else {
          by = kT + kPuckR;
          vy = vy.abs() * 0.9;
          lastEvent = 4;
        }
      }
      if (by > kB - kPuckR) {
        if (inGoal && guard == 0) {
          if (by > kB + kPuckR) {
            _point(false);
            return;
          }
        } else {
          by = kB - kPuckR;
          vy = -vy.abs() * 0.9;
          lastEvent = 4;
        }
      }
    }
    vx *= _friction;
    vy *= _friction;
    // a puck left standing still is handed to the other side
    if (math.sqrt(vx * vx + vy * vy) < 0.4) {
      idle++;
      if (idle > 150) _faceOff(by > kMid ? 1 : 0);
    } else {
      idle = 0;
    }
  }

  void _point(bool mine) {
    if (mine) {
      myGoals++;
      goalsScored++;
      streak++;
      bestStreak = math.max(bestStreak, streak);
      score += 100 + d * 10;
      lastEvent = 2;
      _say('GOAL!');
    } else {
      cpuGoals++;
      goalsConceded++;
      streak = 0;
      lastEvent = 3;
      _say('GOAL ×');
    }
    if (!matchMode) {
      _faceOff(mine ? 1 : 0);
      if (!mine) {
        shield = 0;
        hit();
      }
      return;
    }
    if (myGoals >= toWin) {
      matchesWon++;
      score += 500;
      win();
      return;
    }
    if (cpuGoals >= toWin) {
      if (meta.zen) {
        _setupMatch();
        return;
      }
      shield = 0;
      hit();
      return;
    }
    _faceOff(mine ? 1 : 0);
  }

  @override
  void onLifeLost() {
    if (matchMode) {
      _setupMatch();
    } else {
      _faceOff(0);
    }
  }

  @override
  bool useBooster() {
    // Goal guard: for ten seconds the puck cannot enter your goal.
    if (over) return false;
    guard = 600;
    return true;
  }

  @override
  double get progress => matchMode ? (myGoals / toWin).clamp(0.0, 1.0) : 0;

  @override
  String get goalText => matchMode ? '$myGoals-$cpuGoals' : '$goalsScored';

  @override
  Map<String, int> get stats => {
        'goals_scored': goalsScored,
        'matches_won': matchesWon,
        'saves': saves,
        'best_streak': bestStreak,
      };

  @override
  int get stars {
    if (!won) return 0;
    final q = cpuGoals == 0 ? 3 : (cpuGoals < toWin ~/ 2 + 1 ? 2 : 1);
    return math.min(lifeStars(this, 3), q);
  }
}

// ---- Çevrimiçi düello ----

const _flashes = ['', 'GOAL!', 'GOAL ×'];

/// Autopilot: defends from its own half and shoots for the far corner of the
/// goal, away from the rival's mallet.
ArcadeInput hockeyBot(ArcadeSim sim) {
  final s = sim as HockeySim;
  ArcadeInput go(double x, double y) => ArcadeInput(
        down: true,
        x: clampD(x, 0, kWorldW).roundToDouble(),
        y: clampD(y + kFingerOffset, 0, kWorldH).roundToDouble(),
      );
  if (s.by < kMid - 10) return go(500 + (s.bx - 500) * 0.5, kB - 160);
  const gy = kT - 40;
  final aim = 500.0 + (s.cx > 500 ? -1 : 1) * 125;
  var ux = aim - s.bx, uy = gy - s.by;
  final n = math.sqrt(ux * ux + uy * uy);
  ux /= n;
  uy /= n;
  const reach = kPuckR + kMalletR + 12;
  final bxp = s.bx - ux * reach, byp = s.by - uy * reach;
  final dx = s.mx - bxp, dy = s.my - byp;
  if (s.my > s.by + 10 && math.sqrt(dx * dx + dy * dy) < 26) return go(s.bx + ux * 60, s.by + uy * 60);
  if (s.my < s.by + 10) {
    final side = s.mx < s.bx ? -1 : 1;
    return go(s.bx + side * (kPuckR + kMalletR + 20), s.by + kPuckR + kMalletR + 30);
  }
  return go(bxp, byp);
}
