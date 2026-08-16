import 'package:flutter/material.dart';

/// A small, reusable loading treatment that matches the app's translucent UI.
///
/// It deliberately keeps the familiar progress ring, while the gentle pulse
/// makes full-page waits feel less abrupt. Motion is paused when the platform
/// requests reduced animation.
class AppLoadingIndicator extends StatefulWidget {
  const AppLoadingIndicator({super.key, this.size = 64, this.label});

  const AppLoadingIndicator.compact({super.key}) : size = 18, label = null;

  final double size;
  final String? label;

  @override
  State<AppLoadingIndicator> createState() => _AppLoadingIndicatorState();
}

class _AppLoadingIndicatorState extends State<AppLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _controller.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = widget.size <= 24;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final iconSize = widget.size * (compact ? 0.42 : 0.34);

    final indicator = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = disableAnimations
            ? 1.0
            : 0.94 + (_controller.value * 0.06);
        return Transform.scale(scale: pulse, child: child);
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.primary.withOpacity(compact ? 0.12 : 0.16),
          border: Border.all(color: Colors.white.withOpacity(0.62)),
          boxShadow: compact
              ? null
              : [
                  BoxShadow(
                    color: scheme.primary.withOpacity(0.18),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: widget.size * 0.72,
              height: widget.size * 0.72,
              child: CircularProgressIndicator(
                strokeWidth: compact ? 2 : 2.6,
                strokeCap: StrokeCap.round,
                color: scheme.primary,
                backgroundColor: scheme.primary.withOpacity(0.18),
              ),
            ),
            Icon(Icons.insights_rounded, size: iconSize, color: scheme.primary),
          ],
        ),
      ),
    );

    return Semantics(
      label: widget.label ?? 'Loading',
      liveRegion: true,
      child: widget.label == null
          ? indicator
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                indicator,
                const SizedBox(height: 14),
                Text(
                  widget.label!,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Centers the standard loading indicator for screen- and tab-level waits.
class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key, this.label = 'Loading your data'});

  final String label;

  @override
  Widget build(BuildContext context) =>
      Center(child: AppLoadingIndicator(label: label));
}
