import 'package:flutter_test/flutter_test.dart';
import 'package:hangly/cutout.dart';
import 'package:image/image.dart' as img;

void main() {
  test('cuts a painted checkerboard, keeps inner white, trims margins', () {
    // 200×200 opaque checkerboard (white / light grey, like AI "transparency").
    final src = img.Image(width: 200, height: 200);
    for (var y = 0; y < 200; y++) {
      for (var x = 0; x < 200; x++) {
        final light = ((x ~/ 10) + (y ~/ 10)).isEven;
        src.setPixelRgba(x, y, light ? 255 : 204, light ? 255 : 204, light ? 255 : 204, 255);
      }
    }
    // A brown "creature" from (60,40) to (139,179) with white "teeth" inside.
    img.fillRect(src, x1: 60, y1: 40, x2: 139, y2: 179, color: img.ColorRgba8(110, 80, 40, 255));
    img.fillRect(src, x1: 90, y1: 150, x2: 109, y2: 160, color: img.ColorRgba8(255, 255, 255, 255));

    final out = img.decodePng(prepareCharmArt(img.encodePng(src))!)!;

    expect(out.width, 80);
    expect(out.height, 140);
    expect(out.getPixel(40, 70).a, 255, reason: 'body stays opaque');
    expect(out.getPixel(40, 115).a, 255, reason: 'enclosed white teeth are kept');
    expect(out.getPixel(40, 115).r, 255);
  });

  test('leaves really transparent art alone apart from trimming', () {
    final src = img.Image(width: 100, height: 100, numChannels: 4);
    img.fillRect(src, x1: 20, y1: 0, x2: 79, y2: 89, color: img.ColorRgba8(250, 250, 250, 255));

    final out = img.decodePng(prepareCharmArt(img.encodePng(src))!)!;

    expect(out.width, 60);
    expect(out.height, 90);
    expect(out.getPixel(30, 45).a, 255, reason: 'white art on real transparency is not cut');
  });
}
