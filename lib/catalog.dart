import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Charm {
  const Charm(this.id, this.name, this.category, {this.emoji, this.image, this.path, this.tags = ''});

  final String id;
  final String name;
  final String category;
  final String? emoji;

  /// Picture art (bundled PNGs and imported charms); emoji otherwise.
  final ImageProvider? image;

  /// Where an imported charm's file lives, on desktop.
  final String? path;

  /// Extra words for search ("places, materials").
  final String tags;

  /// Added by the user with Import Charm… (listed under Creatures).
  bool get imported => id.startsWith('file:');

  /// Picture charms (bundled or imported) hold the cord themselves — jaws,
  /// claws or a loop at the top edge — so they get no bail ring. Only emoji
  /// need one.
  bool get grips => image != null;
}

const imageTypes = XTypeGroup(label: 'Images', extensions: ['png', 'webp', 'gif', 'jpg', 'jpeg']);

/// "my_spider-man.png" → "my spider man".
String displayName(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final base = dot > 0 ? fileName.substring(0, dot) : fileName;
  return base.replaceAll(RegExp(r'[_-]+'), ' ');
}

/// Creatures holds picture art only: PNGs bundled in assets/charms/creatures/
/// and everything the user imports.
const categories = ['Protection', 'Luck & Fortune', 'Ritual & Home', 'Creatures', 'Classic'];

// Emoji up to Unicode 12 only, so they all render with Windows 10's
// Segoe UI Emoji.
const builtInCharms = <Charm>[
  Charm('nazar', 'Nazar boncuğu', 'Protection', emoji: '🧿', tags: 'turkey evil eye glass blue'),
  Charm('nimbu', 'Nimbu', 'Protection', emoji: '🍋', tags: 'india lemon nimbu-mirchi'),
  Charm('mirchi', 'Mirchi', 'Protection', emoji: '🌶️', tags: 'india chilli nimbu-mirchi'),
  Charm('ghanta', 'Ghanta', 'Protection', emoji: '🔔', tags: 'india bell brass temple'),
  Charm('drishti', 'Drishti mask', 'Protection', emoji: '👹', tags: 'india japan demon mask'),
  Charm('shield', 'Shield', 'Protection', emoji: '🛡️', tags: 'metal'),
  Charm('eye', 'Watchful eye', 'Protection', emoji: '👁️', tags: 'eye'),
  Charm('garlic', 'Garlic', 'Protection', emoji: '🧄', tags: 'europe vampire'),
  Charm('clover', 'Four-leaf clover', 'Luck & Fortune', emoji: '🍀', tags: 'ireland green'),
  Charm('ladybug', 'Ladybug', 'Luck & Fortune', emoji: '🐞', tags: 'europe insect'),
  Charm('star', 'Star', 'Luck & Fortune', emoji: '⭐', tags: 'gold'),
  Charm('dice', 'Dice', 'Luck & Fortune', emoji: '🎲', tags: 'game'),
  Charm('moneybag', 'Money bag', 'Luck & Fortune', emoji: '💰', tags: 'gold wealth'),
  Charm('elephant', 'Elephant', 'Luck & Fortune', emoji: '🐘', tags: 'india thailand'),
  Charm('fish', 'Koi fish', 'Luck & Fortune', emoji: '🐟', tags: 'china japan'),
  Charm('rainbow', 'Rainbow', 'Luck & Fortune', emoji: '🌈', tags: 'sky'),
  Charm('diya', 'Diya', 'Ritual & Home', emoji: '🪔', tags: 'india lamp clay diwali'),
  Charm('om', 'Om', 'Ritual & Home', emoji: '🕉️', tags: 'india hindu'),
  Charm('lantern', 'Lantern', 'Ritual & Home', emoji: '🏮', tags: 'china japan paper red'),
  Charm('windchime', 'Wind chime', 'Ritual & Home', emoji: '🎐', tags: 'japan glass furin'),
  Charm('beads', 'Prayer beads', 'Ritual & Home', emoji: '📿', tags: 'mala rosary wood'),
  Charm('marigold', 'Marigold', 'Ritual & Home', emoji: '🌼', tags: 'india flower garland'),
  Charm('coconut', 'Coconut', 'Ritual & Home', emoji: '🥥', tags: 'india kerala'),
  Charm('crescent', 'Crescent & star', 'Ritual & Home', emoji: '☪️', tags: 'islam'),
  Charm('cross', 'Cross', 'Ritual & Home', emoji: '✝️', tags: 'christian'),
  Charm('dharma', 'Dharma wheel', 'Ritual & Home', emoji: '☸️', tags: 'buddhist'),
  Charm('trishul', 'Trishul', 'Ritual & Home', emoji: '🔱', tags: 'india shiva trident'),
  Charm('kite', 'Kite', 'Ritual & Home', emoji: '🪁', tags: 'india uttarayan'),
  Charm('heart', 'Heart', 'Classic', emoji: '❤️', tags: 'love red'),
  Charm('diamond', 'Diamond', 'Classic', emoji: '💎', tags: 'gem crystal'),
  Charm('camera', 'Camera', 'Classic', emoji: '📷', tags: 'photo'),
  Charm('bead', 'Bead', 'Classic', emoji: '🔵', tags: 'glass blue'),
  Charm('moon', 'Moon', 'Classic', emoji: '🌙', tags: 'night'),
  Charm('teddy', 'Teddy', 'Classic', emoji: '🧸', tags: 'toy plush'),
  Charm('balloon', 'Balloon', 'Classic', emoji: '🎈', tags: 'party red'),
  Charm('cherries', 'Cherries', 'Classic', emoji: '🍒', tags: 'fruit'),
  Charm('key', 'Old key', 'Classic', emoji: '🗝️', tags: 'brass metal'),
  Charm('rocket', 'Rocket', 'Classic', emoji: '🚀', tags: 'space'),
  Charm('unicorn', 'Unicorn', 'Classic', emoji: '🦄', tags: 'magic'),
  Charm('chick', 'Chick', 'Classic', emoji: '🐥', tags: 'bird yellow'),
  Charm('guitar', 'Guitar', 'Classic', emoji: '🎸', tags: 'music'),
  Charm('sneaker', 'Sneaker', 'Classic', emoji: '👟', tags: 'shoe car mirror'),
];

const _bundledDir = 'assets/charms/creatures/';
var _bundled = <Charm>[];

/// Finds the creature PNGs shipped in assets/charms/creatures/; each file
/// becomes a charm named after it. Call once at startup.
Future<void> loadBundledCharms() async {
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    _bundled = [
      for (final path in manifest.listAssets())
        if (path.startsWith(_bundledDir) && RegExp(r'\.(png|webp)$', caseSensitive: false).hasMatch(path))
          _bundledCharm(path),
    ];
  } catch (_) {}
}

Charm _bundledCharm(String path) {
  final file = path.substring(_bundledDir.length);
  final name = displayName(file);
  return Charm(
    'asset:${file.toLowerCase()}',
    '${name[0].toUpperCase()}${name.substring(1)}',
    'Creatures',
    image: AssetImage(path),
    tags: 'creature',
  );
}

/// Emoji built-ins plus the bundled creature PNGs.
List<Charm> builtInsWithArt() => [...builtInCharms, ..._bundled];

Charm? findCharm(List<Charm> all, String id) {
  for (final c in all) {
    if (c.id == id) return c;
  }
  return null;
}

/// Base edge length of a charm at 100%.
const charmBase = 84.0;

/// Draws a charm hanging from its top-centre: a small metal bail ring,
/// then the art.
class CharmView extends StatelessWidget {
  const CharmView(this.charm, {super.key, required this.size, this.ring = true});

  final Charm charm;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final Widget art = charm.image != null
        ? Image(
            image: charm.image!,
            width: size,
            height: size,
            fit: BoxFit.contain,
            // Art is trimmed to its pixels; keep the grip at the top edge.
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => Icon(Icons.broken_image, size: size * .6),
          )
        : SizedBox(
            width: size,
            height: size,
            child: FittedBox(
              child: Text(
                charm.emoji!,
                style: const TextStyle(fontSize: 100, height: 1.15, fontFamily: 'Segoe UI Emoji'),
              ),
            ),
          );
    if (!ring || charm.grips) return art;
    final r = math.max(4.0, size * .07);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: r * 2,
          height: r * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFC9A44C), width: math.max(1.5, r * .45)),
          ),
        ),
        art,
      ],
    );
  }
}

/// Height of a [CharmView] with its ring.
double charmHeight(double size) => size + math.max(4.0, size * .07) * 2;

// ---------------------------------------------------------------- ropes

enum RopeKind { solid, twist, chain, beads }

class RopeStyle {
  const RopeStyle(this.id, this.name, this.kind, this.a, this.b, {this.width = 4});
  final String id;
  final String name;
  final RopeKind kind;
  final Color a;
  final Color b;
  final double width;
}

const ropes = <RopeStyle>[
  RopeStyle('twist_pink', 'Candy twist', RopeKind.twist, Color(0xFFE85BB5), Color(0xFF4F7BFF)),
  RopeStyle('kalava', 'Kalava thread', RopeKind.twist, Color(0xFFD62828), Color(0xFFF6C000)),
  RopeStyle('jute', 'Jute', RopeKind.twist, Color(0xFFB08850), Color(0xFF7A5A2E), width: 5),
  RopeStyle('black', 'Black cord', RopeKind.solid, Color(0xFF1E1E1E), Color(0xFF1E1E1E), width: 3),
  RopeStyle('silk_red', 'Red silk', RopeKind.solid, Color(0xFFB3122E), Color(0xFFB3122E), width: 3),
  RopeStyle('gold_chain', 'Gold chain', RopeKind.chain, Color(0xFFD4AF37), Color(0xFF8C6D1F)),
  RopeStyle('silver_chain', 'Silver chain', RopeKind.chain, Color(0xFFC8CCD2), Color(0xFF7B8088)),
  RopeStyle('rudraksha', 'Rudraksha beads', RopeKind.beads, Color(0xFF7B3F1D), Color(0xFF4A2410), width: 7),
  RopeStyle('pearls', 'Pearls', RopeKind.beads, Color(0xFFF7F2EA), Color(0xFFCFC6B8), width: 6),
];

RopeStyle ropeById(String id) => ropes.firstWhere((r) => r.id == id, orElse: () => ropes.first);

Path smoothPath(List<Offset> pts) {
  final p = Path()..moveTo(pts.first.dx, pts.first.dy);
  if (pts.length == 2) return p..lineTo(pts[1].dx, pts[1].dy);
  for (var i = 1; i < pts.length - 1; i++) {
    final mid = Offset.lerp(pts[i], pts[i + 1], .5)!;
    p.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
  }
  return p..lineTo(pts.last.dx, pts.last.dy);
}

void paintRope(Canvas canvas, List<Offset> pts, RopeStyle s) {
  final path = smoothPath(pts);
  final w = s.width;
  final shadow = Paint()
    ..color = const Color(0x33000000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = w + 2
    ..strokeCap = StrokeCap.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
  canvas.save();
  canvas.translate(1.5, 2);
  canvas.drawPath(path, shadow);
  canvas.restore();

  switch (s.kind) {
    case RopeKind.solid:
      canvas.drawPath(
        path,
        Paint()
          ..color = s.a
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round,
      );
    case RopeKind.twist:
      canvas.drawPath(
        path,
        Paint()
          ..color = s.a
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round,
      );
      final stripe = Paint()
        ..color = s.b
        ..strokeWidth = w * .55
        ..strokeCap = StrokeCap.round;
      _along(path, w * 1.4, (pos, tan) {
        final n = Offset(-tan.dy, tan.dx) * (w * .5);
        final t = tan * (w * .45);
        canvas.drawLine(pos - n - t, pos + n + t, stripe);
      });
    case RopeKind.chain:
      final outer = Paint()
        ..color = s.b
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6;
      final inner = Paint()
        ..color = s.a
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      var flat = false;
      _along(path, 5.5, (pos, tan) {
        final angle = math.atan2(tan.dy, tan.dx);
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(angle);
        final r = Rect.fromCenter(center: Offset.zero, width: 8, height: flat ? 2.5 : 5);
        canvas.drawOval(r, outer);
        canvas.drawOval(r, inner);
        canvas.restore();
        flat = !flat;
      });
    case RopeKind.beads:
      canvas.drawPath(
        path,
        Paint()
          ..color = s.b
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      final r = w / 2;
      _along(path, w * 1.05, (pos, _) {
        canvas.drawCircle(
          pos,
          r,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-.4, -.4),
              colors: [Color.lerp(s.a, Colors.white, .45)!, s.a, s.b],
              stops: const [0, .5, 1],
            ).createShader(Rect.fromCircle(center: pos, radius: r)),
        );
      });
  }
}

void _along(Path path, double step, void Function(Offset pos, Offset tan) f) {
  for (final m in path.computeMetrics()) {
    for (var d = step / 2; d < m.length; d += step) {
      final t = m.getTangentForOffset(d);
      if (t != null) f(t.position, t.vector);
    }
  }
}
