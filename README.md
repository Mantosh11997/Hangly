# Hangly

Charms that hang from the top of your Windows screen on a cord, swing with
gravity and a light breeze, and sway when your mouse brushes past. Built
with Flutter.

- Up to 3 charms on a cord, 9 cord styles, size and position controls.
- Emoji charms (Protection, Luck & Fortune, Ritual & Home, Classic) and
  picture **Creatures**: PNGs bundled in `assets/charms/creatures/` or added
  with **Import Charm…**. Imports get any fake checkerboard/white background
  removed and their margins trimmed.
- The charms live in a transparent, click-through, always-on-top window, so
  they never get in the way.

## Run

```
flutter run -d windows   # needs Visual Studio "Desktop development with C++"
flutter run -d chrome    # browser preview on a pretend desktop
```

`hangly.exe` opens the Library window; it starts `hangly.exe --overlay`, the
window the charms hang in, which keeps running after the Library is closed.

## Download

Every push to `main` builds the Windows app in GitHub Actions; grab
`Hangly-windows-x64` from the run's artifacts. Pushing a `v*` tag also
attaches a zip to a GitHub release.
