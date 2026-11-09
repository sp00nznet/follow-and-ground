# Changelog

## 0.2.0 (2026-11-08)

### Changed
- Rebuilt as a Godot 4.7 desktop app for Windows, macOS and Linux (single download, no install). The browser version
  is retired.
- MIT license.

### Added
- 3D room with a choice of object (orb, buddy, ring) and movement (side to side, figure eight, circle, near and far).
- Optional white, pink or brown noise that pans left and right with the object.
- OpenXR: opens in a VR headset when a runtime is present (not yet tested on real hardware).
- Offline voice through the operating system's text-to-speech.
- Ratings kept in the app's user folder, with "Delete my data".
- `tools/selftest.gd` (session rules, paths, noise) and `tools/shots.gd` (screenshots).
- References section and PHILOSOPHY.md.

### Removed
- Camera eye-follow indicator and mic level meter from the browser version.

## 0.1.0

- Browser prototype: safety screen, calm place, bilateral dot sets, rating, grounding, Stop / Ground me.
