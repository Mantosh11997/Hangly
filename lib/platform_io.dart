import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'catalog.dart';
import 'library_app.dart';
import 'overlay.dart';
import 'store_io.dart';

Future<void> start(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadBundledCharms();
  final store = await IoStore.open();
  if (args.contains('--overlay')) {
    await runOverlay(store);
    return;
  }
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(size: Size(1180, 780), minimumSize: Size(900, 600), center: true, title: 'Hangly'),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
  final config = store.load();
  if (config.visible) unawaited(store.startOverlay());
  runApp(LibraryApp(store: store, config: config));
}
