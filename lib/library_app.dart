import 'dart:async';

import 'package:flutter/material.dart';

import 'catalog.dart';
import 'config.dart';
import 'store.dart';

ThemeData hanglyTheme() => ThemeData(
  colorSchemeSeed: const Color(0xFF1565C0),
  fontFamily: 'Segoe UI',
  scaffoldBackgroundColor: const Color(0xFFF6F6F8),
);

class LibraryApp extends StatelessWidget {
  const LibraryApp({super.key, required this.store, required this.config});
  final Store store;
  final HanglyConfig config;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hangly',
      debugShowCheckedModeBanner: false,
      theme: hanglyTheme(),
      home: LibraryPage(store: store, config: config),
    );
  }
}

enum _Page { cord, library, placement, about }

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.store, required this.config});
  final Store store;
  final HanglyConfig config;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late final HanglyConfig c = widget.config;
  late List<Charm> charms = allCharms(widget.store);
  _Page page = _Page.library;
  bool ropesTab = false;
  int slot = 0;
  String filter = 'All';
  String query = '';
  Timer? _saveTimer;

  void _change(VoidCallback f) {
    setState(f);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 120), () => widget.store.save(c));
  }

  void _setCount(int n) {
    _change(() {
      const extras = ['bead', 'star', 'heart'];
      while (c.charms.length < n) {
        c.charms.add(extras[c.charms.length % extras.length]);
      }
      if (c.charms.length > n) c.charms.removeRange(n, c.charms.length);
      slot = slot.clamp(0, n - 1);
    });
  }

  void _pick(Charm ch) {
    _change(() {
      c.charms[slot] = ch.id;
      c.recent
        ..remove(ch.id)
        ..insert(0, ch.id);
      if (c.recent.length > 16) c.recent.removeLast();
    });
  }

  void _move(int dir) {
    final to = slot + dir;
    if (to < 0 || to >= c.charms.length) return;
    _change(() {
      final t = c.charms[slot];
      c.charms[slot] = c.charms[to];
      c.charms[to] = t;
      slot = to;
    });
  }

  Future<void> _import() async {
    final id = await widget.store.importCharm();
    if (id == null) return;
    setState(() => charms = allCharms(widget.store));
    final added = findCharm(charms, id);
    if (added != null) _pick(added);
  }

  Future<void> _deleteImported(Charm ch) async {
    await widget.store.deleteImported(ch);
    _change(() {
      for (var i = 0; i < c.charms.length; i++) {
        if (c.charms[i] == ch.id) c.charms[i] = 'nazar';
      }
      c.favourites.remove(ch.id);
      c.recent.remove(ch.id);
      charms = allCharms(widget.store);
    });
  }

  Charm _charmAt(int i) => findCharm(charms, c.charms[i]) ?? builtInCharms.first;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 820 && box.maxHeight >= 560;
          if (!wide && page == _Page.cord) return _narrow(_cordScroll());
          if (wide && page == _Page.cord) page = _Page.library;
          final body = switch (page) {
            _Page.library || _Page.cord => _library(),
            _Page.placement => _placement(),
            _Page.about => _about(),
          };
          if (!wide) return _narrow(body);
          return Row(
            children: [
              SizedBox(
                width: 320,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _nav(Icons.sentiment_satisfied_alt_outlined, 'Library', _Page.library),
                      _nav(Icons.tune, 'Placement', _Page.placement),
                      _nav(Icons.help_outline, 'About', _Page.about),
                      const Divider(height: 24),
                      ..._cordPanel(),
                      Expanded(
                        child: Center(child: FittedBox(child: _bigPreview())),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE4E4EA)),
                  ),
                  child: body,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Small windows: pages become chips along the top, and the cord panel
  /// gets its own page.
  Widget _narrow(Widget body) {
    const pages = {
      _Page.cord: 'On the cord',
      _Page.library: 'Library',
      _Page.placement: 'Placement',
      _Page.about: 'About',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          child: Row(
            children: [
              for (final e in pages.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: page == e.key,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => page = e.key),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ColoredBox(color: Colors.white, child: body),
        ),
      ],
    );
  }

  Widget _cordScroll() => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      ..._cordPanel(),
      const SizedBox(height: 12),
      Center(child: _bigPreview()),
    ],
  );

  Widget _bigPreview() {
    final selected = _charmAt(slot);
    return CharmView(selected, size: 150 * c.sizeOf(selected.id).clamp(.6, 1.3));
  }

  // ------------------------------------------------------------ cord panel

  List<Widget> _cordPanel() {
    final selected = _charmAt(slot);
    final size = c.sizeOf(selected.id);
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(switch (c.charms.length) {
          1 => 'One charm hangs on the cord.',
          2 => 'Two charms hang on the cord.',
          _ => 'Three charms hang on the cord.',
        }, style: const TextStyle(fontSize: 15)),
      ),
      const SizedBox(height: 8),
      for (var i = 0; i < c.charms.length; i++) _slotTile(i),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton(onPressed: slot > 0 ? () => _move(-1) : null, child: const Text('Move up')),
          OutlinedButton(onPressed: slot < c.charms.length - 1 ? () => _move(1) : null, child: const Text('Move down')),
        ],
      ),
      const SizedBox(height: 18),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text('Size of ${selected.name} — ${(size * 100).round()}% of its own'),
      ),
      Slider(value: size, min: .5, max: 3, divisions: 50, onChanged: (v) => _change(() => c.sizes[selected.id] = v)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text('${selected.name} · ${selected.category}', style: TextStyle(color: Colors.grey.shade600)),
      ),
    ];
  }

  Widget _nav(IconData icon, String label, _Page p) {
    final on = page == p;
    return Material(
      color: on ? const Color(0xFFEAEAF0) : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => setState(() => page = p),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Container(width: 3, height: 18, color: on ? Theme.of(context).colorScheme.primary : null),
              const SizedBox(width: 10),
              Icon(icon, size: 22),
              const SizedBox(width: 14),
              Text(label, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slotTile(int i) {
    final ch = _charmAt(i);
    final on = i == slot;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: on ? const Color(0xFFEAEAF0) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => setState(() => slot = i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Container(width: 3, height: 26, color: on ? Theme.of(context).colorScheme.primary : null),
                const SizedBox(width: 12),
                CharmView(ch, size: 34, ring: false),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(ch.name, style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ library

  Widget _library() {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
          sliver: SliverToBoxAdapter(child: _libraryHeader()),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          sliver: ropesTab ? _ropeGrid() : _charmBrowser(),
        ),
      ],
    );
  }

  Widget _libraryHeader() {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        const Text('Library', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w600)),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Charms')),
            ButtonSegment(value: true, label: Text('Ropes')),
          ],
          selected: {ropesTab},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => ropesTab = s.first),
        ),
        const SizedBox(width: 8),
        RadioGroup<int>(
          groupValue: c.charms.length,
          onChanged: (v) => _setCount(v!),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final n in [1, 2, 3]) ...[
                Radio<int>(value: n),
                Text('$n charm${n > 1 ? 's' : ''}', style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _charmBrowser() {
    final q = query.trim().toLowerCase();
    final list = charms.where((ch) {
      final inFilter = switch (filter) {
        'All' => true,
        'Favourites' => c.favourites.contains(ch.id),
        'Recent' => c.recent.contains(ch.id),
        _ => ch.category == filter,
      };
      final inQuery = q.isEmpty || '${ch.name} ${ch.category} ${ch.tags}'.toLowerCase().contains(q);
      return inFilter && inQuery;
    }).toList();
    if (filter == 'Recent') {
      list.sort((a, b) => c.recent.indexOf(a.id).compareTo(c.recent.indexOf(b.id)));
    }

    final controls = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search charms, places, materials',
                  suffixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => query = v),
              ),
            ),
            OutlinedButton(onPressed: _import, child: const Text('Import Charm…')),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in ['All', 'Favourites', 'Recent', ...categories])
              ChoiceChip(
                label: Text(f),
                selected: filter == f,
                showCheckmark: false,
                onSelected: (_) => setState(() => filter = f),
              ),
          ],
        ),
        const SizedBox(height: 14),
      ],
    );

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: controls),
        if (list.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Text(
                  filter == 'Creatures' ? 'Use Import Charm… to add a creature PNG.' : 'Nothing here yet.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ),
          )
        else
          SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 130,
              mainAxisExtent: 140,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: list.length,
            itemBuilder: (_, i) => _charmTile(list[i]),
          ),
      ],
    );
  }

  Widget _charmTile(Charm ch) {
    final on = c.charms[slot] == ch.id;
    final fav = c.favourites.contains(ch.id);
    return Material(
      color: on ? const Color(0xFFE3ECFA) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _pick(ch),
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CharmView(ch, size: 58),
                  const SizedBox(height: 4),
                  Text(ch.name, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 13.5)),
                ],
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: IconButton(
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                tooltip: fav ? 'Remove from favourites' : 'Add to favourites',
                icon: Icon(
                  fav ? Icons.favorite : Icons.favorite_border,
                  color: fav ? Colors.pink : Colors.grey.shade500,
                ),
                onPressed: () => _change(() => fav ? c.favourites.remove(ch.id) : c.favourites.add(ch.id)),
              ),
            ),
            if (ch.imported)
              Positioned(
                left: 0,
                top: 0,
                child: IconButton(
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Delete imported charm',
                  icon: Icon(Icons.delete_outline, color: Colors.grey.shade500),
                  onPressed: () => _deleteImported(ch),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _ropeGrid() {
    return SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 170,
        mainAxisExtent: 220,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: ropes.length,
      itemBuilder: (_, i) {
        final r = ropes[i];
        final on = c.rope == r.id;
        return Material(
          color: on ? const Color(0xFFE3ECFA) : const Color(0xFFF7F7F9),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _change(() => c.rope = r.id),
            child: Column(
              children: [
                Expanded(
                  child: CustomPaint(painter: _RopePreview(r), size: Size.infinite),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(r.name, style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------ placement

  Widget _placement() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
      children: [
        const Text('Placement', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Show charms on the desktop'),
          subtitle: const Text('They hang from the top edge of your main screen, above every window.'),
          value: c.visible,
          onChanged: (v) {
            _change(() => c.visible = v);
            if (v) {
              // Save first so the new overlay reads visible = true.
              _saveTimer?.cancel();
              widget.store.save(c);
              widget.store.startOverlay();
            }
          },
        ),
        SwitchListTile(
          title: const Text('Swing when the mouse passes'),
          subtitle: const Text('Clicks always go through to the window underneath.'),
          value: c.mouseSwing,
          onChanged: (v) => _change(() => c.mouseSwing = v),
        ),
        const SizedBox(height: 16),
        ListTile(
          title: const Text('Position across the screen'),
          subtitle: Slider(value: c.xFraction, min: .02, max: .98, onChanged: (v) => _change(() => c.xFraction = v)),
          trailing: Text('${(c.xFraction * 100).round()}%'),
        ),
        ListTile(
          title: const Text('Cord length'),
          subtitle: Slider(value: c.ropeLength, min: 40, max: 600, onChanged: (v) => _change(() => c.ropeLength = v)),
          trailing: Text('${c.ropeLength.round()} px'),
        ),
        ListTile(
          title: const Text('Keep swinging'),
          subtitle: Slider(value: c.swing, min: 0, max: 25, onChanged: (v) => _change(() => c.swing = v)),
          trailing: Text(c.swing < .5 ? 'Still' : '${c.swing.round()}°'),
        ),
      ],
    );
  }

  Widget _about() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
      children: [
        const Text('About', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        const Text(
          'Hangly hangs little charms from the top of your screen, like an ornament on a '
          'rear-view mirror. Pick up to three charms and a cord, place them anywhere along '
          'the top edge, and flick them with your mouse.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 16),
        Text(widget.store.charmFolderLabel, style: TextStyle(color: Colors.grey.shade700, height: 1.5)),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.power_settings_new),
            label: const Text('Take charms down and quit'),
            onPressed: () {
              _saveTimer?.cancel();
              setState(() => c.visible = false);
              widget.store.save(c);
              widget.store.quit();
            },
          ),
        ),
      ],
    );
  }
}

class _RopePreview extends CustomPainter {
  _RopePreview(this.style);
  final RopeStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final pts = [for (var i = 0; i <= 12; i++) Offset(cx + 18 * (i / 12) * (i / 12), 14 + (size.height - 28) * i / 12)];
    paintRope(canvas, pts, style);
  }

  @override
  bool shouldRepaint(_RopePreview old) => old.style != style;
}
