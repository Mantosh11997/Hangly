import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'catalog.dart';
import 'config.dart';

const _segment = 8.0;
const _gap = 12.0;

/// Fastest a cord point may move per physics step (120 Hz), ~480 px/s.
const _maxStep = 4.0;

/// Room the charms need below the anchor, for sizing the overlay window.
double hangingHeight(HanglyConfig c, List<Charm> all) => _Layout(c, all).total + 60;

/// Where along the cord each charm sits, measured from the anchor.
class _Layout {
  _Layout(HanglyConfig c, List<Charm> all) {
    var d = c.ropeLength;
    for (final id in c.charms) {
      final charm = findCharm(all, id);
      if (charm == null) continue;
      final size = charmBase * c.sizeOf(id);
      final h = charm.grips ? size : charmHeight(size);
      slots.add(_Slot(charm, size, d, h));
      d += h + _gap;
    }
    ropeEnd = slots.isEmpty ? c.ropeLength : slots.last.start;
    total = slots.isEmpty ? c.ropeLength : slots.last.start + slots.last.height;
  }

  final slots = <_Slot>[];
  late final double ropeEnd;
  late final double total;
}

class _Slot {
  _Slot(this.charm, this.size, this.start, this.height);
  final Charm charm;
  final double size;
  final double start;
  final double height;
}

/// A cord as a chain of points (Verlet integration). Charm bodies are
/// heavier than the cord and held rigid by an extra constraint.
class _Rope {
  _Rope(this.layout, Offset anchor) {
    final n = (layout.total / _segment).ceil();
    for (var i = 0; i <= n; i++) {
      final p = anchor + Offset(0, math.min(i * _segment, layout.total));
      pos.add(p);
      prev.add(p);
      invMass.add(1);
    }
    invMass[0] = 0;
    for (final s in layout.slots) {
      final a = index(s.start), b = index(s.start + s.height);
      for (var i = a; i <= b; i++) {
        invMass[i] = .25;
      }
      rigid.add((a, b, (b - a) * _segment));
    }
  }

  final _Layout layout;
  final pos = <Offset>[];
  final prev = <Offset>[];
  final invMass = <double>[];
  final rigid = <(int, int, double)>[];

  int index(double d) => (d / _segment).round().clamp(0, pos.length - 1);

  void moveAnchor(Offset to) => pos[0] = prev[0] = to;

  /// Advances the cord by [dt]. [swing] is the angle (radians, each side)
  /// the charms keep swinging at on their own.
  void step(double dt, double t, Offset? push, Offset pushAt, double pushRadius, double swing) {
    const gravity = 1600.0;
    const damping = .985;
    // A slow, uneven breeze so the charm is never perfectly still.
    final breeze = math.sin(t * .9) * 14 + math.sin(t * 2.3 + 1) * 6;
    final drive = breeze + _pump(dt, gravity, swing);
    for (var i = 1; i < pos.length; i++) {
      var v = (pos[i] - prev[i]) * damping;
      if (push != null && (pos[i] - pushAt).distance < pushRadius) v += push;
      // Cap speed so a fast flick swings the charm instead of launching it.
      if (v.distance > _maxStep) v = v / v.distance * _maxStep;
      prev[i] = pos[i];
      pos[i] = pos[i] + v + Offset(drive, gravity) * dt * dt;
    }
    for (var k = 0; k < 24; k++) {
      for (var i = 0; i < pos.length - 1; i++) {
        _solve(i, i + 1, _segment);
      }
      for (final (a, b, len) in rigid) {
        _solve(a, b, len);
      }
    }
  }

  /// Sideways push that keeps the cord swinging at [swing], like pumping a
  /// playground swing: push the way it's already moving while the swing is
  /// smaller than wanted, and let damping take it down when it's bigger
  /// (after a mouse hit, say). The cord is treated as one pendulum from the
  /// knot to its last point.
  double _pump(double dt, double gravity, double swing) {
    if (swing <= 0) return 0;
    final d = pos.last - pos[0];
    final r2 = d.distanceSquared;
    if (r2 < 1) return 0;
    final v = (pos.last - prev.last) / dt;
    final angle = math.atan2(d.dx, d.dy);
    final angularVelocity = (d.dy * v.dx - d.dx * v.dy) / r2;
    final omega = math.sqrt(gravity / math.sqrt(r2));
    // Peak angle this swing will reach (phase-plane amplitude).
    final amplitude = math.sqrt(angle * angle + math.pow(angularVelocity / omega, 2));
    if (amplitude >= swing) return 0;
    final direction = angularVelocity.abs() < 1e-3 ? 1.0 : angularVelocity.sign;
    return direction * 450;
  }

  void _solve(int a, int b, double len) {
    final wa = invMass[a], wb = invMass[b];
    if (wa + wb == 0) return;
    final delta = pos[b] - pos[a];
    final dist = delta.distance;
    if (dist == 0) return;
    final corr = delta * ((dist - len) / dist / (wa + wb));
    pos[a] += corr * wa;
    pos[b] -= corr * wb;
  }

  Offset at(double d) => pos[index(d)];
}

/// Charms swinging on a cord tied at [anchor]. Ignores pointer input; the
/// mouse only matters through [cursor], which returns the pointer position
/// in this widget's coordinates (or null when unknown).
class HangingCharms extends StatefulWidget {
  const HangingCharms({super.key, required this.config, required this.charms, required this.anchor, this.cursor});

  final HanglyConfig config;
  final List<Charm> charms;
  final Offset anchor;
  final Offset? Function()? cursor;

  @override
  State<HangingCharms> createState() => _HangingCharmsState();
}

class _HangingCharmsState extends State<HangingCharms> with SingleTickerProviderStateMixin {
  late _Layout layout;
  late _Rope rope;
  late String shape;
  late final Ticker ticker;
  Duration last = Duration.zero;
  double acc = 0;
  Offset? lastCursor;

  /// Anything that changes the cord's length or the charms on it.
  String _shape() {
    final c = widget.config;
    return jsonEncode([
      c.charms,
      [for (final id in c.charms) c.sizeOf(id)],
      c.ropeLength,
      [
        for (final ch in widget.charms)
          if (ch.imported) ch.id,
      ],
    ]);
  }

  void _rebuild() {
    shape = _shape();
    layout = _Layout(widget.config, widget.charms);
    rope = _Rope(layout, widget.anchor);
  }

  @override
  void initState() {
    super.initState();
    _rebuild();
    ticker = createTicker(_tick)..start();
  }

  @override
  void didUpdateWidget(HangingCharms old) {
    super.didUpdateWidget(old);
    if (_shape() != shape) {
      _rebuild();
    } else if (old.anchor != widget.anchor) {
      // Drag the knot; the physics carries the rest along with a swing.
      rope.moveAnchor(widget.anchor);
    }
  }

  void _tick(Duration now) {
    var dt = (now - last).inMicroseconds / 1e6;
    last = now;
    if (dt > .1) dt = .1;
    acc += dt;

    // Batting the charm: shove any cord point the pointer sweeps through.
    Offset? push;
    var at = Offset.zero;
    final c = widget.config.mouseSwing ? widget.cursor?.call() : null;
    if (c != null && lastCursor != null) {
      final d = c - lastCursor!;
      if (d.distance > 2 && d.distance < 200) {
        // Hand the charm part of the pointer's velocity (d is per frame,
        // push is per physics step).
        push = d * .05;
        if (push.distance > 1.5) push = push / push.distance * 1.5;
        at = c;
      }
    }
    lastCursor = c;

    const h = 1 / 120;
    final reach = layout.slots.fold(20.0, (m, s) => math.max(m, s.size)) * .55;
    final swing = widget.config.swing * math.pi / 180;
    var first = true;
    while (acc >= h) {
      rope.step(h, now.inMicroseconds / 1e6, first ? push : null, at, reach, swing);
      first = false;
      acc -= h;
    }
    setState(() {});
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = ropeById(widget.config.rope);
    final drawn = rope.pos.sublist(0, rope.index(layout.ropeEnd) + 1);
    return IgnorePointer(
      // Charms sit outside any Material, so give emoji text a plain style.
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final s in layout.slots) _charm(s, shadow: true),
            Positioned.fill(child: CustomPaint(painter: _RopePainter(drawn, style))),
            for (final s in layout.slots) _charm(s),
          ],
        ),
      ),
    );
  }

  /// A charm, or with [shadow] its soft shadow: the same art, flattened to
  /// translucent black, blurred and dropped down-right as if lit from the
  /// upper left. It falls on whatever window sits behind the charm.
  Widget _charm(_Slot s, {bool shadow = false}) {
    final top = rope.at(s.start);
    final bottom = rope.at(s.start + s.height);
    final angle = math.atan2(bottom.dx - top.dx, bottom.dy - top.dy);
    final drop = shadow ? Offset(s.size * .08, s.size * .14) : Offset.zero;
    Widget art = CharmView(s.charm, size: s.size);
    if (shadow) {
      art = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: s.size * .05, sigmaY: s.size * .05),
        child: ColorFiltered(colorFilter: const ColorFilter.mode(Color(0x59000000), BlendMode.srcIn), child: art),
      );
    }
    return Positioned(
      left: top.dx - s.size / 2 + drop.dx,
      top: top.dy + drop.dy,
      child: Transform.rotate(angle: -angle, alignment: Alignment.topCenter, child: art),
    );
  }
}

class _RopePainter extends CustomPainter {
  _RopePainter(this.points, this.style);
  final List<Offset> points;
  final RopeStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length >= 2) paintRope(canvas, points, style);
  }

  @override
  bool shouldRepaint(_RopePainter old) => true;
}
