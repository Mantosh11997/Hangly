import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'catalog.dart';
import 'config.dart';
import 'hanging.dart';
import 'store.dart';
import 'store_io.dart';
import 'win.dart';

const _overlayWidth = 520.0;
const _anchor = Offset(_overlayWidth / 2, -2);

/// The always-on-top, click-through, transparent window the charms hang in.
Future<void> runOverlay(IoStore store) async {
  // One overlay at a time: a second copy finds the lock taken and leaves.
  try {
    final raf = store.lockFile.openSync(mode: FileMode.write);
    raf.lockSync(FileLock.exclusive);
  } catch (_) {
    exit(0);
  }

  final config = store.load();
  if (!config.visible) exit(0);

  await windowManager.ensureInitialized();
  final dpr = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
  final rect = _windowRect(config, allCharms(store), dpr);

  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      size: rect.size,
      backgroundColor: Colors.transparent,
      skipTaskbar: true,
      alwaysOnTop: true,
      titleBarStyle: TitleBarStyle.hidden,
      title: 'Hangly charm',
    ),
    () async {
      await windowManager.setAsFrameless();
      await windowManager.setBackgroundColor(Colors.transparent);
      await windowManager.setIgnoreMouseEvents(true);
      await windowManager.setBounds(rect);
      await windowManager.show(inactive: true);
    },
  );

  runApp(OverlayApp(store: store, initial: config, initialRect: rect));
}

Rect _windowRect(HanglyConfig c, List<Charm> all, double dpr) {
  final screen = primaryScreenPhysical() / dpr;
  final h = math.min(hangingHeight(c, all), screen.height);
  final x = (screen.width * c.xFraction - _overlayWidth / 2).clamp(
    -_overlayWidth / 2,
    screen.width - _overlayWidth / 2,
  );
  return Rect.fromLTWH(x.toDouble(), 0, _overlayWidth, h);
}

class OverlayApp extends StatefulWidget {
  const OverlayApp({super.key, required this.store, required this.initial, required this.initialRect});
  final IoStore store;
  final HanglyConfig initial;
  final Rect initialRect;

  @override
  State<OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<OverlayApp> {
  late HanglyConfig config = widget.initial;
  late List<Charm> charms = allCharms(widget.store);
  late Rect rect = widget.initialRect;
  Timer? poll;
  DateTime? seen;

  @override
  void initState() {
    super.initState();
    seen = widget.store.modified();
    poll = Timer.periodic(const Duration(milliseconds: 400), (_) => _checkConfig());
  }

  Future<void> _checkConfig() async {
    final m = widget.store.modified();
    if (m == null || m == seen) return;
    seen = m;
    final next = widget.store.load();
    if (!next.visible) {
      await windowManager.destroy();
      exit(0);
    }
    if (!mounted) return;
    final dpr = View.of(context).devicePixelRatio;
    setState(() {
      config = next;
      charms = allCharms(widget.store);
      rect = _windowRect(config, charms, dpr);
    });
    await windowManager.setBounds(rect);
  }

  /// The window ignores the mouse, so read the global cursor instead.
  Offset _cursor() => cursorPhysical() / View.of(context).devicePixelRatio - rect.topLeft;

  @override
  void dispose() {
    poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      home: ColoredBox(
        color: Colors.transparent,
        child: HangingCharms(config: config, charms: charms, anchor: _anchor, cursor: _cursor),
      ),
    );
  }
}
