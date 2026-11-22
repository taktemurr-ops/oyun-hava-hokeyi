import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:studio_core/app/arcade_stage.dart';
import 'package:studio_core/app/play_kit.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/arcade.dart';
import 'hockey_engine.dart';

Paint _p(int c) => Paint()..color = Color(c);

Paint _stroke(int c, double w) => Paint()
  ..color = Color(c)
  ..style = PaintingStyle.stroke
  ..strokeWidth = w;

void _mallet(Canvas c, double x, double y, int color) {
  c.drawCircle(Offset(x + 6, y + 10), kMalletR, _p(0x55000000));
  c.drawCircle(Offset(x, y), kMalletR, _p(color));
  c.drawCircle(Offset(x, y), kMalletR * 0.62, _p(0x33000000));
  c.drawCircle(Offset(x, y), kMalletR * 0.42, _p(color));
  c.drawCircle(Offset(x - 8, y - 10), kMalletR * 0.18, _p(0x66FFFFFF));
}

void paintHockey(Canvas c, ArcadeSim sim, ArcadePalette p, double t) {
  final s = sim as HockeySim;
  const themes = [
    [0xFF0B132B, 0xFFE0FBFC, 0xFF3A86FF],
    [0xFF1B1B3A, 0xFFF1FAEE, 0xFFE63946],
    [0xFF132A13, 0xFFF0F3BD, 0xFF2A9D8F],
    [0xFF240046, 0xFFF8F9FA, 0xFFFF9E00],
  ];
  final th = themes[s.level.theme % 4];
  c.drawRect(const Rect.fromLTWH(0, 0, kWorldW, kWorldH), _p(th[0]));
  final table = Rect.fromLTRB(kL, kT, kR, kB);
  // rails
  c.drawRRect(RRect.fromRectAndRadius(table.inflate(34), const Radius.circular(60)), _p(0xFF343A40));
  c.drawRRect(RRect.fromRectAndRadius(table, const Radius.circular(40)), _p(th[1]));
  // air holes
  for (var y = kT + 40; y < kB; y += 80) {
    for (var x = kL + 40; x < kR; x += 80) {
      c.drawCircle(Offset(x, y), 3, _p(0x22000000));
    }
  }
  final line = _stroke(th[2], 6);
  c.drawLine(const Offset(kL, kMid), const Offset(kR, kMid), line);
  c.drawCircle(const Offset(500, kMid), 110, line);
  c.drawArc(Rect.fromCircle(center: const Offset(500, kT), radius: 210), 0, math.pi, false, _stroke(0x88E63946, 5));
  c.drawArc(Rect.fromCircle(center: const Offset(500, kB), radius: 210), math.pi, math.pi, false, _stroke(0x883A86FF, 5));
  // goal slots
  c.drawRect(const Rect.fromLTRB(500 - kGoalHalf, kT - 34, 500 + kGoalHalf, kT + 6), _p(0xFF111111));
  c.drawRect(const Rect.fromLTRB(500 - kGoalHalf, kB - 6, 500 + kGoalHalf, kB + 34), _p(0xFF111111));
  if (s.guard > 0) {
    final a = (0.5 + 0.5 * math.sin(t * 10)) * 0.6 + 0.3;
    c.drawRect(const Rect.fromLTRB(500 - kGoalHalf, kB - 14, 500 + kGoalHalf, kB + 4),
        Paint()..color = const Color(0xFF4CC9F0).withValues(alpha: a));
  }
  // puck
  c.drawCircle(Offset(s.bx + 4, s.by + 7), kPuckR, _p(0x55000000));
  c.drawCircle(Offset(s.bx, s.by), kPuckR, _p(0xFF212529));
  c.drawCircle(Offset(s.bx, s.by), kPuckR * 0.7, _stroke(0xFFFFD60A, 4));
  _mallet(c, s.cx, s.cy, 0xFFE63946);
  _mallet(c, s.mx, s.my, 0xFF3A86FF);
  // score
  paintText(c, '${s.cpuGoals}', const Offset(940, kMid - 70), 56, Colors.white70);
  paintText(c, '${s.myGoals}', const Offset(940, kMid + 70), 56, Colors.white);
  if (s.pause > 0 && s.by > kMid) {
    paintText(c, '▲', Offset(s.bx, s.by + 110 + 10 * math.sin(t * 6)), 50, Colors.black45);
  }
  if (s.flashTicks > 0) {
    paintText(c, s.flash, const Offset(500, kMid), 90, Colors.white.withValues(alpha: (s.flashTicks / 60).clamp(0.0, 1.0)));
  }
}

Sfx? hockeySound(ArcadeSim sim) => switch ((sim as HockeySim).lastEvent) {
      1 => Sfx.tap,
      2 => Sfx.combo,
      3 => Sfx.error,
      4 => Sfx.place,
      _ => null,
    };
