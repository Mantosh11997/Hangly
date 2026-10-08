import 'dart:ffi' hide Size;
import 'dart:ui';

import 'package:ffi/ffi.dart';

// The few user32 calls the overlay needs; hand-bound so we don't depend on
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
final _findWindow = _user32
    .lookupFunction<IntPtr Function(Pointer<Utf16>, Pointer<Utf16>), int Function(Pointer<Utf16>, Pointer<Utf16>)>(
      'FindWindowW',
    );
final _setLayeredWindowAttributes = _user32
    .lookupFunction<Int32 Function(IntPtr, Uint32, Uint8, Uint32), int Function(int, int, int, int)>(
      'SetLayeredWindowAttributes',
    );

const _lwaAlpha = 2;

/// Makes the window titled [title] fully opaque as a layered window.
///
/// window_manager's click-through adds WS_EX_LAYERED but never sets the
/// layered opacity, and Windows does not draw a layered window until it has
/// one: the overlay ran but stayed invisible. Per-pixel transparency still
/// works afterwards.
void showLayeredWindow(String title) {
  final t = title.toNativeUtf16();
  final hwnd = _findWindow(nullptr, t);
  calloc.free(t);
  if (hwnd != 0) _setLayeredWindowAttributes(hwnd, 0, 255, _lwaAlpha);
}

final Pointer<_Point> _pt = calloc<_Point>();

/// Global cursor position in physical pixels.
Offset cursorPhysical() {
  _getCursorPos(_pt);
  return Offset(_pt.ref.x.toDouble(), _pt.ref.y.toDouble());
}

/// Primary screen size in physical pixels.
Size primaryScreenPhysical() => Size(_getSystemMetrics(0).toDouble(), _getSystemMetrics(1).toDouble());
