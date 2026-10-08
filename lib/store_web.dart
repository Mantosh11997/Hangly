import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'catalog.dart';
import 'config.dart';
import 'cutout.dart';
import 'store.dart';

/// In-memory store for the browser preview. Imported images live only for
/// the session. Listeners (the page drawing the charms) hear every save.
class WebStore extends ChangeNotifier implements Store {
  HanglyConfig _config = HanglyConfig();
  final _imported = <Charm>[];

  HanglyConfig get config => _config;

  @override
  HanglyConfig load() => _config.copy();

  @override
  void save(HanglyConfig c) {
    _config = c.copy();
    notifyListeners();
  }

  @override
  List<Charm> importedCharms() => List.unmodifiable(_imported);

  @override
  Future<String?> importCharm() async {
    final file = await openFile(acceptedTypeGroups: const [imageTypes]);
    if (file == null) return null;
    final raw = await file.readAsBytes();
    final bytes = await compute(prepareCharmArt, raw) ?? raw;
    final id = 'file:${file.name}';
    _imported
      ..removeWhere((c) => c.id == id)
      ..add(
        Charm(id, displayName(file.name), 'Creatures', image: MemoryImage(bytes), tags: 'imported custom creature'),
      );
    return id;
  }

  @override
  Future<void> deleteImported(Charm c) async => _imported.removeWhere((x) => x.id == c.id);

  @override
  String get charmFolderLabel => 'In the browser preview, imported charms last until you reload the page.';

  @override
  Future<void> startOverlay() async {}

  @override
  void quit() {
    _config.visible = false;
    notifyListeners();
  }
}
