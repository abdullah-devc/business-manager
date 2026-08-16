// app_background_controller.dart
//
// A tiny app-wide singleton that lets screens deep in the widget tree
// (AuthGate, HomePage's tab bar) talk to WaveBackground, which lives
// up at the MaterialApp `builder` level — above the Navigator, above
// AuthGate, above everything. Rather than plumbing callbacks all the
// way up through the widget tree, screens just poke these three
// ValueNotifiers and WaveBackground reacts.
//
// - `animate`: true = keep animating continuously (lock/login screen).
//              false = freeze; only re-render when `variant` changes.
// - `variant`: bump this to whatever "look" you want the frozen
//              background to show (e.g. the active tab index). Each
//              distinct value renders its own still frame, with a
//              short slide+fade transition between values.
// - `brightness`: 0.0 (dark) .. 1.0 (light, the original look). Lets
//              the user dim the background toward a dark-mode feel
//              without touching the rest of the (still light) UI.
//              Persisted to the app_settings table so it survives a
//              restart; call `loadPersisted()` once at startup after
//              the database is ready.
import 'package:flutter/material.dart';

import '../database_helper.dart';

class AppBackgroundController {
  AppBackgroundController._();
  static final AppBackgroundController instance = AppBackgroundController._();

  static const _brightnessKey = 'background_brightness';

  final ValueNotifier<bool> animate = ValueNotifier<bool>(true);
  final ValueNotifier<int> variant = ValueNotifier<int>(0);
  final ValueNotifier<double> brightness = ValueNotifier<double>(1.0);
  bool _isDarkModeTransition = false;

  /// True only while the Dark Mode switch is applying its visual change.
  /// WaveBackground uses this to cross-fade between its light and dark
  /// frames. Slider changes remain immediate so dragging stays responsive.
  bool get isDarkModeTransition => _isDarkModeTransition;

  /// Loads the persisted brightness value from the database. Call once
  /// during app startup, after `DatabaseHelper.instance.database` has
  /// been awaited.
  Future<void> loadPersisted() async {
    final stored = await DatabaseHelper.instance.getAppSetting(_brightnessKey);
    final parsed = stored == null ? null : double.tryParse(stored);
    if (parsed != null) {
      brightness.value = parsed.clamp(0.0, 1.0);
    }
  }

  /// Updates the live value immediately (so the background responds as
  /// the user drags a slider) and persists it to disk.
  Future<void> setBrightness(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    brightness.value = clamped;
    await DatabaseHelper.instance.setAppSetting(_brightnessKey, clamped.toString());
  }

  /// True once the background has been dimmed past the midpoint. Used
  /// to decide what the "Dark Mode" menu toggle should show/do next —
  /// there's no separate persisted flag, brightness is the single
  /// source of truth.
  bool get isDarkMode => brightness.value <= 0.5;

  /// One-tap shortcut that jumps straight to the dark or light end of
  /// the brightness range (the slider still allows anything in
  /// between). Persists like `setBrightness` and marks this specific
  /// change for a short visual transition.
  Future<void> toggleDarkMode() async {
    _isDarkModeTransition = true;
    await setBrightness(isDarkMode ? 1.0 : 0.0);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    _isDarkModeTransition = false;
  }

  /// Readable primary text/icon color for content sitting directly on
  /// WaveBackground (no glass panel behind it) at a given brightness —
  /// near-black on the light end, near-white on the dark end.
  ///
  /// This deliberately does NOT fade smoothly across the whole 0..1
  /// range. A plain linear fade from white to black means text passes
  /// through a flat mid-gray right around brightness 0.5 — precisely
  /// where the wave background is also at its least contrasty — so the
  /// two would wash into each other and the text would disappear. This
  /// commits to white or black within a narrow band around the
  /// midpoint instead, so text stays close to full-contrast for almost
  /// the entire slider range and only spends a small stretch actually
  /// transitioning.
  static Color adaptiveTextColor(double brightness) {
    final double t = _contrastCurve(brightness.clamp(0.0, 1.0));
    return Color.lerp(Colors.white, const Color(0xDD000000), t)!;
  }

  /// Same idea as [adaptiveTextColor] but for secondary/subtitle text.
  static Color adaptiveSecondaryTextColor(double brightness) {
    final double t = _contrastCurve(brightness.clamp(0.0, 1.0));
    return Color.lerp(Colors.white70, Colors.black54, t)!;
  }

  /// Maps brightness (0..1) to a mixing weight that stays pinned near 0
  /// or 1 for most of the range and only sweeps through the middle in
  /// a narrow band, via a smoothstep over [lo, hi].
  static double _contrastCurve(double brightness, {double lo = 0.48, double hi = 0.52}) {
    final double t = ((brightness - lo) / (hi - lo)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// Readable text/icon color for content sitting on a *glass* surface
  /// (GlassContainer, GlassBar, GlassActionButton) rather than bare
  /// WaveBackground. Glass panels lay a translucent white tint over
  /// whatever's behind them, so they stay noticeably lighter than the
  /// raw background at any given brightness — but at the very dark end
  /// of the slider they still get dark enough that pinned-black text
  /// stops being readable. This uses the same white<->near-black curve
  /// as [adaptiveTextColor], just shifted so the crossover happens much
  /// further down the brightness range (glass text should stay dark
  /// until the background is genuinely quite dark, not just dimmed).
  static Color adaptiveGlassTextColor(double brightness) {
    final double t = _contrastCurve(brightness.clamp(0.0, 1.0), lo: 0.16, hi: 0.30);
    return Color.lerp(Colors.white, const Color(0xDD000000), t)!;
  }

  /// Same idea as [adaptiveGlassTextColor] but for secondary/subtitle
  /// text on glass surfaces.
  static Color adaptiveGlassSecondaryTextColor(double brightness) {
    final double t = _contrastCurve(brightness.clamp(0.0, 1.0), lo: 0.16, hi: 0.30);
    return Color.lerp(Colors.white70, Colors.black54, t)!;
  }
}
