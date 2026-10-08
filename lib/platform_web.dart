import 'package:flutter/material.dart';

import 'catalog.dart';
import 'hanging.dart';
import 'library_app.dart';
import 'store.dart';
import 'store_web.dart';

Future<void> start(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadBundledCharms();
  runApp(WebShell(store: WebStore()));
}

/// The browser stands in for the desktop: a wallpaper, the Library window
/// floating on it, and the charms hanging from the top of the page over
/// everything.
class WebShell extends StatefulWidget {
  const WebShell({super.key, required this.store});
  final WebStore store;

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  Offset? pointer;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hangly',
      debugShowCheckedModeBanner: false,
      theme: hanglyTheme(),
      home: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerHover: (e) => pointer = e.localPosition,
        onPointerMove: (e) => pointer = e.localPosition,
        child: LayoutBuilder(
          builder: (context, box) {
            final narrow = box.maxWidth < 760;
            return Stack(
              children: [
                const Positioned.fill(child: _Wallpaper()),
                Positioned(
                  left: narrow ? 8 : 48,
                  right: narrow ? 8 : box.maxWidth * .12,
                  top: narrow ? 70 : 64,
                  bottom: narrow ? 8 : 40,
                  child: _FakeWindow(
                    child: LibraryPage(store: widget.store, config: widget.store.load()),
                  ),
                ),
                Positioned.fill(
                  child: ListenableBuilder(
                    listenable: widget.store,
                    builder: (context, _) {
                      final c = widget.store.config;
                      if (!c.visible) return const SizedBox.shrink();
                      return HangingCharms(
                        config: c,
                        charms: allCharms(widget.store),
                        anchor: Offset(box.maxWidth * c.xFraction, -2),
                        cursor: () => pointer,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Wallpaper extends StatelessWidget {
  const _Wallpaper();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9FC5E8), Color(0xFFB4A7D6), Color(0xFFF4CCCC)],
        ),
      ),
    );
  }
}

class _FakeWindow extends StatelessWidget {
  const _FakeWindow({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 18,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      color: const Color(0xFFF6F6F8),
      child: Column(
        children: [
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            color: Colors.white,
            child: Row(
              children: [
                const Text('🧿', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                const Text('Hangly', style: TextStyle(fontSize: 13)),
                const Spacer(),
                for (final i in [Icons.remove, Icons.crop_square, Icons.close])
                  Padding(
                    padding: const EdgeInsets.only(left: 22),
                    child: Icon(i, size: 15, color: Colors.grey.shade700),
                  ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
