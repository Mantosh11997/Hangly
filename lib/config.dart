/// Everything the overlay needs to draw the hanging charms. On Windows the
/// Library window writes it to disk and the overlay process polls it; on the
/// web it just lives in memory.
class HanglyConfig {
  HanglyConfig({
    List<String>? charms,
    Map<String, double>? sizes,
    this.rope = 'twist_pink',
    this.xFraction = 0.82,
    this.ropeLength = 220,
    this.visible = true,
    this.mouseSwing = true,
    this.swing = 8,
    Set<String>? favourites,
    List<String>? recent,
  }) : charms = charms ?? ['nazar'],
       sizes = sizes ?? {},
       favourites = favourites ?? {},
       recent = recent ?? [];

  /// Top to bottom on the cord, 1–3 entries.
  List<String> charms;

  /// Scale per charm id (1.0 = 100%).
  Map<String, double> sizes;
  String rope;

  /// Horizontal anchor as a fraction of the screen width.
  double xFraction;

  /// Cord length above the first charm, in logical pixels.
  double ropeLength;
  bool visible;
  bool mouseSwing;

  /// How far the charms keep swinging on their own, in degrees each side
  /// (0 = they settle and hang still).
  double swing;
  Set<String> favourites;
  List<String> recent;

  double sizeOf(String id) => sizes[id] ?? 1.0;

  HanglyConfig copy() => HanglyConfig.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    'charms': [...charms],
    'sizes': {...sizes},
    'rope': rope,
    'xFraction': xFraction,
    'ropeLength': ropeLength,
    'visible': visible,
    'mouseSwing': mouseSwing,
    'swing': swing,
    'favourites': favourites.toList(),
    'recent': [...recent],
  };

  factory HanglyConfig.fromJson(Map<String, dynamic> j) => HanglyConfig(
    charms: (j['charms'] as List?)?.cast<String>(),
    sizes: (j['sizes'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toDouble())),
    rope: j['rope'] as String? ?? 'twist_pink',
    xFraction: (j['xFraction'] as num?)?.toDouble() ?? 0.82,
    ropeLength: (j['ropeLength'] as num?)?.toDouble() ?? 220,
    visible: j['visible'] as bool? ?? true,
    mouseSwing: j['mouseSwing'] as bool? ?? true,
    swing: (j['swing'] as num?)?.toDouble() ?? 8,
    favourites: (j['favourites'] as List?)?.cast<String>().toSet(),
    recent: (j['recent'] as List?)?.cast<String>(),
  );
}
