import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Prepares charm art on import and returns it as PNG bytes, or null if the
/// bytes aren't an image.
///
/// AI image tools often fake transparency: the "transparent" background is
/// a white or grey checkerboard painted into an opaque image. When the
/// corners are opaque, any light, unsaturated colour reachable from the
/// border is cut out. A flood fill from the edges keeps light details
/// inside the creature (teeth, eyes). Then the empty margins are trimmed,
/// so the grip at the top touches the top edge where the cord attaches.
Uint8List? prepareCharmArt(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final w = decoded.width, h = decoded.height;
  final px = decoded.convert(format: img.Format.uint8, numChannels: 4).getBytes(order: img.ChannelOrder.rgba);

  int alpha(int i) => px[i * 4 + 3];
  final opaqueCorners = [0, w - 1, (h - 1) * w, h * w - 1].every((i) => alpha(i) > 250);
  if (opaqueCorners) _cutBackground(px, w, h);

  final cropped = _trim(img.Image.fromBytes(width: w, height: h, bytes: px.buffer, numChannels: 4));
  return img.encodePng(cropped);
}

/// White, and the light greys of a painted checkerboard.
bool _isBackground(Uint8List px, int i) {
  final r = px[i * 4], g = px[i * 4 + 1], b = px[i * 4 + 2];
  final lo = r < g ? (r < b ? r : b) : (g < b ? g : b);
  final hi = r > g ? (r > b ? r : b) : (g > b ? g : b);
  return lo > 165 && hi - lo < 28;
}

void _cutBackground(Uint8List px, int w, int h) {
  final gone = Uint8List(w * h);
  final stack = <int>[];
  void seed(int i) {
    if (gone[i] == 0 && _isBackground(px, i)) {
      gone[i] = 1;
      stack.add(i);
    }
  }

  for (var x = 0; x < w; x++) {
    seed(x);
    seed((h - 1) * w + x);
  }
  for (var y = 0; y < h; y++) {
    seed(y * w);
    seed(y * w + w - 1);
  }
  while (stack.isNotEmpty) {
    final i = stack.removeLast();
    final x = i % w;
    if (x > 0) seed(i - 1);
    if (x < w - 1) seed(i + 1);
    if (i >= w) seed(i - w);
    if (i < (h - 1) * w) seed(i + w);
  }

  for (var i = 0; i < w * h; i++) {
    if (gone[i] == 1) {
      px[i * 4 + 3] = 0;
      continue;
    }
    // Soften the one-pixel rim where the art was blended into the light
    // background, so it doesn't leave a pale halo.
    final x = i % w;
    final edge =
        (x > 0 && gone[i - 1] == 1) ||
        (x < w - 1 && gone[i + 1] == 1) ||
        (i >= w && gone[i - w] == 1) ||
        (i < (h - 1) * w && gone[i + w] == 1);
    if (edge) px[i * 4 + 3] = 150;
  }
}

/// Crops to the visible pixels.
img.Image _trim(img.Image im) {
  var top = im.height, left = im.width, bottom = -1, right = -1;
  for (var y = 0; y < im.height; y++) {
    for (var x = 0; x < im.width; x++) {
      if (im.getPixel(x, y).a > 16) {
        if (y < top) top = y;
        if (y > bottom) bottom = y;
        if (x < left) left = x;
        if (x > right) right = x;
      }
    }
  }
  if (bottom < 0) return im;
  return img.copyCrop(im, x: left, y: top, width: right - left + 1, height: bottom - top + 1);
}
