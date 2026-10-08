import 'platform_io.dart' if (dart.library.js_interop) 'platform_web.dart';

/// Windows: `hangly.exe` opens the Library window and `hangly.exe --overlay`
/// is the transparent window the charms hang in.
/// Web: one page with the Library window on a pretend desktop.
Future<void> main(List<String> args) => start(args);
