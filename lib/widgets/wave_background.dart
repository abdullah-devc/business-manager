// wave_background.dart
//
// A Flutter port of the JS canvas "hero wave" background, with a
// white base instead of the original dark navy/purple base.
//
// BEHAVIOR
// --------
// Driven by AppBackgroundController.instance (see
// app_background_controller.dart):
//
//   - animate == true  -> keeps animating continuously. Intended for
//     the lock/login screen, where a lively background is nice and the
//     screen is only up briefly.
//   - animate == false -> freezes. The background stops recomputing
//     every frame entirely (this is the big performance win — no more
//     continuous background isolate work fighting your app for CPU).
//     It only re-renders when `variant` changes (e.g. wire it to your
//     active tab index), producing a new still frame for that variant
//     with a short slide + fade transition, then holding still again
//     until the next change.
//
// Usage:
//   Stack(
//     children: [
//       const Positioned.fill(child: WaveBackground()),
//       // ...your foreground content...
//     ],
//   )
//
// Then, elsewhere in your app:
//   AppBackgroundController.instance.animate.value = false;   // on unlock
//   AppBackgroundController.instance.animate.value = true;    // on lock
//   AppBackgroundController.instance.variant.value = tabIndex; // on tab switch
//
// PERFORMANCE
// -----------
// The pixel math (a double loop with 4 trig warp iterations per pixel)
// runs inside `compute()`, which hands the work to a pooled background
// isolate rather than the UI isolate — so it never blocks your app's
// build/layout/paint. In frozen mode this only runs once per tab
// switch, so steady-state CPU cost while browsing a tab is ~zero.
//
// Remaining tuning knobs if the *lock screen's* continuous animation
// still feels heavy:
//   1. `targetFps`  — lower = fewer frames recomputed per second.
//   2. `scale`      — higher = fewer pixels per frame.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'app_background_controller.dart';

class WaveBackground extends StatefulWidget {
  const WaveBackground({
    super.key,
    this.scale = 4,
    this.targetFps = 15,
    this.transitionDuration = const Duration(milliseconds: 550),
  });

  /// Downsample factor for the internal render buffer. Higher = faster,
  /// blockier.
  final int scale;

  /// Caps how often we regenerate the pixel buffer per second while in
  /// continuous (lock-screen) mode.
  final int targetFps;

  /// How long the slide+fade transition takes when `variant` changes
  /// in frozen mode.
  final Duration transitionDuration;

  @override
  State<WaveBackground> createState() => _WaveBackgroundState();
}

/// Plain data class passed across the isolate boundary — must only
/// contain simple, transferable values (no widgets/BuildContext/etc).
@immutable
class _WaveParams {
  final int width;
  final int height;
  final double time;
  final double brightness;
  const _WaveParams(this.width, this.height, this.time, this.brightness);
}

// ---------------------------------------------------------------------
// Everything below this line runs on the background isolate when
// invoked via compute(). Keep it free of Flutter widget/BuildContext
// references — only dart:core / dart:math / dart:typed_data.
// ---------------------------------------------------------------------

const int _tableSize = 1024;
Float32List? _sinTable;
Float32List? _cosTable;

void _ensureTables() {
  if (_sinTable != null) return;
  final sin = Float32List(_tableSize);
  final cos = Float32List(_tableSize);
  for (int i = 0; i < _tableSize; i++) {
    final double angle = (i / _tableSize) * math.pi * 2;
    sin[i] = math.sin(angle);
    cos[i] = math.cos(angle);
  }
  _sinTable = sin;
  _cosTable = cos;
}

double _fastSin(double x) {
  final int index =
      (((x % (math.pi * 2)) / (math.pi * 2)) * _tableSize).floor() &
          (_tableSize - 1);
  return _sinTable![index];
}

double _fastCos(double x) {
  final int index =
      (((x % (math.pi * 2)) / (math.pi * 2)) * _tableSize).floor() &
          (_tableSize - 1);
  return _cosTable![index];
}

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

/// Top-level function required by `compute()`. Builds one RGBA frame.
/// Runs on a pooled background isolate — never on the UI thread.
Uint8List _computeWavePixels(_WaveParams p) {
  _ensureTables();
  final int width = p.width;
  final int height = p.height;
  final double time = p.time;
  final double brightness = p.brightness;
  final Uint8List data = Uint8List(width * height * 4);

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final double uX = (2 * x - width) / height;
      final double uY = (2 * y - height) / height;

      double a = 0;
      double d = 0;
      for (int i = 0; i < 4; i++) {
        a += _fastCos(i - d + time * 0.5 - a * uX);
        d += _fastSin(i * uY + a);
      }

      final double wave = (_fastSin(a) + _fastCos(d)) * 0.5;
      final double intensity = 0.3 + 0.4 * wave;
      final double baseVal = 0.1 + 0.15 * _fastCos(uX + uY + time * 0.3);
      final double blueAccent = 0.2 * _fastSin(a * 1.5 + time * 0.2);
      final double purpleAccent = 0.15 * _fastCos(d * 2 + time * 0.1);

      final double r = _clamp01(baseVal + purpleAccent * 0.8) * intensity;
      final double g = _clamp01(baseVal + blueAccent * 0.6) * intensity;
      final double b =
          _clamp01(baseVal + blueAccent * 1.2 + purpleAccent * 0.4) *
              intensity;

      // At brightness == 1 this reproduces the original look: inverted
      // onto a white base, so dark-theme wave values become subtle
      // gray/blue-tinted valleys on an otherwise white field. As
      // brightness drops toward 0 we blend toward the *un-inverted*
      // values instead — the same wave field sitting on a near-black
      // base — giving a continuous light-to-dark range with one field.
      //
      // IMPORTANT: the light-look value is deliberately NOT a pure
      // per-pixel inverse (1 - r) of the dark-look value. Crossfading
      // any pattern with its own exact inverse always washes out to a
      // completely flat, patternless mid-gray at the halfway point of
      // the fade (r*(1-t) + (1-r)*t == 0.5 for every pixel when
      // t == 0.5, regardless of r) — which is what made the background
      // (and any text tuned to match it) go flat and unreadable at the
      // midpoint of the brightness slider. Using a softened inverse
      // (`1 - k*r` with k < 1) keeps the light and dark looks close to
      // their original appearance at the two ends of the slider while
      // guaranteeing the wave pattern never fully cancels out in
      // between.
      const double kLight = 0.55;
      final double lightR = 1 - kLight * r;
      final double lightG = 1 - kLight * g;
      final double lightB = 1 - kLight * b;

      final double outR = r + (lightR - r) * brightness;
      final double outG = g + (lightG - g) * brightness;
      final double outB = b + (lightB - b) * brightness;

      final int idx = (y * width + x) * 4;
      data[idx] = (outR * 255).round().clamp(0, 255);
      data[idx + 1] = (outG * 255).round().clamp(0, 255);
      data[idx + 2] = (outB * 255).round().clamp(0, 255);
      data[idx + 3] = 255;
    }
  }

  return data;
}

/// A decoded frame plus the buffer size it was decoded at (needed for
/// the source rect when we stretch-draw it).
class _Frame {
  final ui.Image image;
  final int width;
  final int height;
  const _Frame(this.image, this.width, this.height);
}

// ---------------------------------------------------------------------
// Widget / State
// ---------------------------------------------------------------------

class _WaveBackgroundState extends State<WaveBackground>
    with TickerProviderStateMixin {
  late final Ticker _liveTicker;
  late final AnimationController _transitionController;
  final Stopwatch _stopwatch = Stopwatch()..start();

  // Continuous (lock-screen) mode state.
  _Frame? _liveFrame;
  Duration _lastLiveFrame = Duration.zero;
  bool _liveRendering = false;

  // Frozen/per-variant mode state.
  _Frame? _staticCurrent;
  _Frame? _staticIncoming;
  double _slideDir = 1.0; // +1 = new content slides in from the right
  bool _fadeOnly = false;
  bool _variantRendering = false;

  bool _animating = true;
  int _variant = 0;
  double _brightness = 1.0;

  @override
  void initState() {
    super.initState();
    _animating = AppBackgroundController.instance.animate.value;
    _variant = AppBackgroundController.instance.variant.value;
    _brightness = AppBackgroundController.instance.brightness.value;

    _liveTicker = createTicker(_onLiveTick);
    _transitionController = AnimationController(
      vsync: this,
      duration: widget.transitionDuration,
    )..addStatusListener(_onTransitionStatus);

    if (_animating) {
      _liveTicker.start();
    } else {
      // Render an initial still frame immediately so we don't sit on a
      // blank white screen if we start up already unlocked.
      _renderVariantFrame(initial: true);
    }

    AppBackgroundController.instance.animate.addListener(_onAnimateChanged);
    AppBackgroundController.instance.variant.addListener(_onVariantChanged);
    AppBackgroundController.instance.brightness.addListener(_onBrightnessChanged);
  }

  void _onAnimateChanged() {
    final bool next = AppBackgroundController.instance.animate.value;
    if (next == _animating) return;
    setState(() => _animating = next);

    if (next) {
      // A Ticker's elapsed duration starts again when it is restarted. Keep
      // the frame-rate gate in the same timebase; otherwise the timestamp
      // from the previous login session can make every new tick look "too
      // soon" and leave a re-locked/password screen visually frozen.
      _lastLiveFrame = Duration.zero;
      _liveTicker.start();
    } else {
      _liveTicker.stop();
      // Snap the frozen view to a clean, deterministic frame for the
      // current variant rather than whatever moment the live ticker
      // happened to stop on.
      _renderVariantFrame(initial: true);
    }
  }

  void _onVariantChanged() {
    final int next = AppBackgroundController.instance.variant.value;
    if (next == _variant) return;
    _slideDir = next > _variant ? 1.0 : -1.0;
    _variant = next;
    if (!_animating) {
      _renderVariantFrame();
    }
  }

  void _onBrightnessChanged() {
    final double next = AppBackgroundController.instance.brightness.value;
    if (next == _brightness) return;
    _brightness = next;
    // Live mode picks up the new brightness on its next scheduled
    // frame automatically. Frozen mode needs an explicit re-render.
    // Slider changes stay immediate, while the Dark Mode switch fades
    // between the two rendered looks to avoid a jarring jump.
    if (!_animating) {
      _renderVariantFrame(
        initial: !AppBackgroundController.instance.isDarkModeTransition,
        fadeOnly: AppBackgroundController.instance.isDarkModeTransition,
      );
    }
  }

  void _onTransitionStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // Promote the incoming frame to "current" and drop the old one.
      final old = _staticCurrent;
      setState(() {
        _staticCurrent = _staticIncoming;
        _staticIncoming = null;
        _fadeOnly = false;
      });
      old?.image.dispose();
      _transitionController.value = 0;
    }
  }

  ({int width, int height})? _bufferSizeFor(BuildContext context) {
    final mq = MediaQuery.maybeOf(context);
    if (mq == null) return null;
    final size = mq.size;
    final dpr = mq.devicePixelRatio;
    final int pxW = (size.width * dpr).round();
    final int pxH = (size.height * dpr).round();
    if (pxW <= 0 || pxH <= 0) return null;
    final int w = math.max(1, pxW ~/ widget.scale);
    final int h = math.max(1, pxH ~/ widget.scale);
    return (width: w, height: h);
  }

  void _onLiveTick(Duration elapsed) {
    if (!_animating || _liveRendering) return;
    final int minIntervalMs = (1000 / widget.targetFps).round();
    if ((elapsed - _lastLiveFrame).inMilliseconds < minIntervalMs) return;
    _lastLiveFrame = elapsed;

    final dims = _bufferSizeFor(context);
    if (dims == null) return;
    final double time = _stopwatch.elapsedMilliseconds * 0.001;

    _liveRendering = true;
    _decodeFrame(dims.width, dims.height, time).then((frame) {
      _liveRendering = false;
      if (!mounted) return;
      final old = _liveFrame;
      setState(() => _liveFrame = frame);
      old?.image.dispose();
    });
  }

  Future<void> _renderVariantFrame({
    bool initial = false,
    bool fadeOnly = false,
  }) async {
    if (_variantRendering) return;
    final dims = _bufferSizeFor(context);
    if (dims == null) return;
    _variantRendering = true;

    // Each variant gets its own deterministic moment in the wave field,
    // so switching back to the same tab always shows the same "look".
    final double time = 1.7 + _variant * 4.3;
    final frame = await _decodeFrame(dims.width, dims.height, time);
    _variantRendering = false;
    if (!mounted) {
      frame.image.dispose();
      return;
    }

    if (initial || _staticCurrent == null) {
      final old = _staticCurrent;
      setState(() => _staticCurrent = frame);
      old?.image.dispose();
      return;
    }

    setState(() {
      _staticIncoming = frame;
      _fadeOnly = fadeOnly;
    });
    _transitionController.forward(from: 0);
  }

  Future<_Frame> _decodeFrame(int width, int height, double time) async {
    final Uint8List data = await compute(
        _computeWavePixels, _WaveParams(width, height, time, _brightness));
    final Completer<ui.Image> completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      data,
      width,
      height,
      ui.PixelFormat.rgba8888,
      (ui.Image img) => completer.complete(img),
    );
    final ui.Image img = await completer.future;
    return _Frame(img, width, height);
  }

  @override
  void dispose() {
    AppBackgroundController.instance.animate.removeListener(_onAnimateChanged);
    AppBackgroundController.instance.variant.removeListener(_onVariantChanged);
    AppBackgroundController.instance.brightness.removeListener(_onBrightnessChanged);
    _liveTicker.dispose();
    _transitionController.dispose();
    _liveFrame?.image.dispose();
    _staticCurrent?.image.dispose();
    _staticIncoming?.image.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Matches the pixel math's light/dark blend so there's no flash of
    // plain white while the very first frame is still being computed.
    final Color fallback = Color.lerp(Colors.black, Colors.white, _brightness) ?? Colors.white;
    return Container(
      color: fallback,
      child: _animating ? _buildLive() : _buildFrozen(),
    );
  }

  Widget _buildLive() {
    if (_liveFrame == null) return const SizedBox.expand();
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _WaveImagePainter(_liveFrame!.image, _liveFrame!.width,
            _liveFrame!.height),
      ),
    );
  }

  Widget _buildFrozen() {
    final current = _staticCurrent;
    if (current == null) return const SizedBox.expand();
    final incoming = _staticIncoming;

    if (incoming == null) {
      // Settled — no transition running, just paint the still frame.
      return RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter:
              _WaveImagePainter(current.image, current.width, current.height),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _transitionController,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_transitionController.value);
        final size = MediaQuery.of(context).size;
        final slidePx = _fadeOnly ? 0.0 : size.width * 0.12;

        return Stack(
          fit: StackFit.expand,
          children: [
            // Outgoing frame slides out and fades away.
            Opacity(
              opacity: (1 - t).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(-_slideDir * slidePx * t, 0),
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _WaveImagePainter(
                        current.image, current.width, current.height),
                  ),
                ),
              ),
            ),
            // Incoming frame slides in from the direction of travel and
            // fades up.
            Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(_slideDir * slidePx * (1 - t), 0),
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _WaveImagePainter(
                        incoming.image, incoming.width, incoming.height),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WaveImagePainter extends CustomPainter {
  _WaveImagePainter(this.image, this.bufW, this.bufH);

  final ui.Image image;
  final int bufW;
  final int bufH;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..filterQuality = FilterQuality.none;
    final Rect src = Rect.fromLTWH(0, 0, bufW.toDouble(), bufH.toDouble());
    final Rect dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant _WaveImagePainter oldDelegate) {
    return oldDelegate.image != image;
  }
}
