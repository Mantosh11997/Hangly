import 'dart:ffi' hide Size;
import 'dart:ui';

import 'package:ffi/ffi.dart';

// The two user32 calls the overlay needs; hand-bound so we don't depend on
// a particular win32 package API.

final class _Point extends Struct {
  @Int32()
  external int x;
  @Int32()
  external int y;
}

final _user32 = DynamicLibrary.open('user32.dll');
final _getCursorPos = _user32.lookupFunction<Int32 Function(Pointer<_Point>), int Function(Pointer<_Point>)>(
  'GetCursorPos',
);
final _getSystemMetrics = _user32.lookupFunction<Int32 Function(Int32), int Function(int)>('GetSystemMetrics');

final Pointer<_Point> _pt = calloc<_Point>();

/// Global cursor position in physical pixels.
Offset cursorPhysical() {
  _getCursorPos(_pt);
  return Offset(_pt.ref.x.toDouble(), _pt.ref.y.toDouble());
}

/// Primary screen size in physical pixels.
Size primaryScreenPhysical() => Size(_getSystemMetrics(0).toDouble(), _getSystemMetrics(1).toDouble());
