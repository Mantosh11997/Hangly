import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

import 'catalog.dart';
import 'config.dart';
import 'cutout.dart';
import 'store.dart';

class IoStore implements Store {
  IoStore._(this.dir);
  final Directory dir;

  static Future<IoStore> open() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}Hangly');
    await Directory('${dir.path}${Platform.pathSeparator}charms').create(recursive: true);
    return IoStore._(dir);
  }

  File get configFile => File('${dir.path}${Platform.pathSeparator}config.json');
  File get lockFile => File('${dir.path}${Platform.pathSeparator}overlay.lock');
  Directory get charmDir => Directory('${dir.path}${Platform.pathSeparator}charms');

  @override
  HanglyConfig load() {
    try {
      return HanglyConfig.fromJson(jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>);
    } catch (_) {
      return HanglyConfig();
    }
  }

  /// Write to a temp file then rename, so the overlay never reads half a file.
  @override
  void save(HanglyConfig c) {
    final tmp = File('${configFile.path}.tmp');
    tmp.writeAsStringSync(jsonEncode(c.toJson()));
    tmp.renameSync(configFile.path);
  }

  DateTime? modified() {
    try {
      return configFile.lastModifiedSync();
    } catch (_) {
      return null;
    }
  }

  @override
  List<Charm> importedCharms() {
    final out = <Charm>[];
    try {
      for (final f in charmDir.listSync().whereType<File>()) {
        final name = f.uri.pathSegments.last;
        out.add(
          Charm(
            'file:$name',
            displayName(name),
            'Creatures',
            image: FileImage(f),
            path: f.path,
            tags: 'imported custom creature',
          ),
        );
      }
    } catch (_) {}
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  @override
  Future<String?> importCharm() async {
    final file = await openFile(acceptedTypeGroups: const [imageTypes]);
    if (file == null) return null;
    final png = await compute(prepareCharmArt, await file.readAsBytes());
    // Cleaned art is always saved as PNG; anything undecodable is kept as is.
    final dot = file.name.lastIndexOf('.');
    final name = png == null ? file.name : '${dot > 0 ? file.name.substring(0, dot) : file.name}.png';
    final dest = File('${charmDir.path}${Platform.pathSeparator}$name');
    if (png != null) {
      await dest.writeAsBytes(png);
    } else {
      await File(file.path).copy(dest.path);
    }
    await FileImage(dest).evict(); // re-importing a name must show the new art
    return 'file:$name';
  }

  @override
  Future<void> deleteImported(Charm c) async {
    try {
      await File(c.path!).delete();
    } catch (_) {}
  }

  @override
  String get charmFolderLabel => 'Imported charms live in:\n${charmDir.path}';

  /// Launches the overlay as a separate process of this same executable.
  /// If one is already running it notices the lock and exits by itself.
  @override
  Future<void> startOverlay() async {
    await Process.start(Platform.resolvedExecutable, ['--overlay'], mode: ProcessStartMode.detached);
  }

  @override
  void quit() => exit(0);
}
