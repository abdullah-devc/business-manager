// glass_tab_bar.dart
//
// A frosted "liquid glass" pill tab bar: a glowing capsule cursor slides
// and resizes to sit behind whichever tab is active, the way the classic
// React "SlideTabs" pattern does — measure each tab's rect, then tween a
// single indicator between them instead of letting each tab manage its
// own selected state.
//
// Two things this version does differently from a naive port:
//   1. The cursor's position is driven directly by the TabController's
//      own animation value (not a separate AnimatedPositioned), so it
//      tracks 1:1 with both taps *and* swipes across TabBarView — swipe
//      halfway and the pill sits halfway between the two tabs, exactly
//      like Flutter's built-in TabBar indicator does.
//   2. Label color crossfades from the app's adaptive glass text color to
//      white as the pill slides under each tab, instead of a hard
//      selected/unselected switch — keeps it feeling like one continuous
//      motion rather than a toggle.
//
// Drop-in replacement for a plain `TabBar` in the AppBar's `bottom:`:
//   bottom: GlassSlideTabBar(
//     controller: _tabController,
//     tabs: const ['Overview', 'Transactions', 'Invoices', ...],
//   ),

import 'package:flutter/material.dart';

import 'app_background_controller.dart';
import 'glass.dart';

class GlassSlideTabBar extends StatefulWidget implements PreferredSizeWidget {
  const GlassSlideTabBar({
    super.key,
    required this.controller,
    required this.tabs,
    this.accent,
  });

  final TabController controller;
  final List<String> tabs;

  /// Cursor color. Defaults to the theme's primary color.
  final Color? accent;

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  State<GlassSlideTabBar> createState() => _GlassSlideTabBarState();
}

class _GlassSlideTabBarState extends State<GlassSlideTabBar> {
  late List<GlobalKey> _keys = List.generate(widget.tabs.length, (_) => GlobalKey());
  final GlobalKey _stackKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  List<Rect> _rects = const [];

  @override
  void initState() {
    super.initState();
    widget.controller.animation?.addListener(_onTick);
    widget.controller.addListener(_onIndexSettled);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(covariant GlassSlideTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.animation?.removeListener(_onTick);
      oldWidget.controller.removeListener(_onIndexSettled);
      widget.controller.animation?.addListener(_onTick);
      widget.controller.addListener(_onIndexSettled);
    }
    if (oldWidget.tabs.length != widget.tabs.length) {
      _keys = List.generate(widget.tabs.length, (_) => GlobalKey());
      _rects = const [];
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }
  }

  @override
  void dispose() {
    widget.controller.animation?.removeListener(_onTick);
    widget.controller.removeListener(_onIndexSettled);
    _scrollController.dispose();
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  // Fires once a swipe across TabBarView settles on a new index (tap
  // already handles this itself via _ensureTabVisible in onTap), so a
  // swipe to an off-screen tab scrolls the bar to reveal it too.
  void _onIndexSettled() {
    if (!widget.controller.indexIsChanging) _ensureTabVisible(widget.controller.index);
  }

  /// Scrolls the tapped tab into view (centered where possible) so tabs
  /// past the edge of the screen are reachable with a tap, not just a
  /// manual swipe — mirrors what Flutter's built-in `TabBar(isScrollable:
  /// true)` does when you tap an off-screen tab.
  void _ensureTabVisible(int i) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tabContext = _keys[i].currentContext;
      if (tabContext == null) return;
      Scrollable.ensureVisible(
        tabContext,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: 0.5,
      );
    });
  }

  /// Measures every tab's rect relative to the shared Stack. Re-run after
  /// first layout and whenever the bar's own size changes (e.g. a window
  /// resize on desktop), so the cursor never targets a stale rect.
  void _measure() {
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || !stackBox.attached) return;
    final rects = <Rect>[];
    for (final key in _keys) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) return;
      final offset = box.localToGlobal(Offset.zero, ancestor: stackBox);
      rects.add(offset & box.size);
    }
    if (mounted && !_rectsEqual(rects, _rects)) {
      setState(() => _rects = rects);
    }
  }

  bool _rectsEqual(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  double get _animValue {
    final raw = widget.controller.animation?.value ?? widget.controller.index.toDouble();
    return raw.clamp(0.0, (widget.tabs.length - 1).toDouble());
  }

  Rect? get _cursorRect {
    if (_rects.length != widget.tabs.length) return null;
    final v = _animValue;
    final lower = v.floor();
    final upper = v.ceil();
    final t = v - lower;
    return Rect.lerp(_rects[lower], _rects[upper], t);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent ?? Theme.of(context).colorScheme.primary;
    final cursor = _cursorRect;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: GlassContainer(
        padding: const EdgeInsets.all(4),
        borderRadius: BorderRadius.circular(28),
        blur: 16,
        opacity: 0.42,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Cheap no-op once rects are already current; re-measures
            // only actually triggers a rebuild when a rect changed.
            WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
            // Scrollable so a long tab list (Overview, Transactions,
            // Invoices, Companies, Inventory, Reports, Settings, ...)
            // never overflows the app bar width on narrow/mobile
            // screens — it scrolls horizontally instead of clipping or
            // pushing the last tabs off-screen. The Row keeps
            // mainAxisSize.min so it sizes to its content and the
            // ScrollView provides the (otherwise unbounded) width for
            // that; rects stay correct because they're measured
            // relative to the Stack itself, not the viewport.
            return SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Stack(
                key: _stackKey,
                children: [
                  if (cursor != null)
                    Positioned(
                      left: cursor.left,
                      top: cursor.top,
                      width: cursor.width,
                      height: cursor.height,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [accent.withOpacity(0.95), accent.withOpacity(0.78)],
                          ),
                          border: Border.all(color: Colors.white.withOpacity(0.55), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(0.45),
                              blurRadius: 16,
                              spreadRadius: -3,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(widget.tabs.length, (i) {
                      final activation = (1 - (_animValue - i).abs()).clamp(0.0, 1.0);
                      return _GlassTab(
                        key: _keys[i],
                        label: widget.tabs[i],
                        activation: activation,
                        onTap: () {
                          widget.controller.animateTo(i);
                          _ensureTabVisible(i);
                        },
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GlassTab extends StatelessWidget {
  const _GlassTab({
    super.key,
    required this.label,
    required this.activation,
    required this.onTap,
  });

  final String label;

  /// 1.0 when the cursor is fully over this tab, fading to 0.0 as it
  /// slides away — drives the text color/weight crossfade.
  final double activation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ValueListenableBuilder<double>(
          valueListenable: AppBackgroundController.instance.brightness,
          builder: (context, brightness, _) {
            final baseColor = AppBackgroundController.adaptiveGlassTextColor(brightness);
            final color = Color.lerp(baseColor, Colors.white, activation)!;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                constraints: const BoxConstraints(minWidth: 64),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.lerp(FontWeight.w500, FontWeight.w700, activation),
                    fontSize: 13.5,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}