import 'catalog.dart';
import 'config.dart';

/// What the Library window needs from the platform. Windows keeps things in
/// files and runs the charms in a separate overlay process; the web keeps
/// them in memory and draws the charms on the same page.
abstract class Store {
  HanglyConfig load();
  void save(HanglyConfig c);

  List<Charm> importedCharms();

  /// Opens a file picker; returns the new charm's id, or null if cancelled.
  Future<String?> importCharm();
  Future<void> deleteImported(Charm c);

  /// Shown on the About page.
  String get charmFolderLabel;

  Future<void> startOverlay();

  /// "Take charms down and quit".
  void quit();
}

List<Charm> allCharms(Store store) => [...builtInsWithArt(), ...store.importedCharms()];
