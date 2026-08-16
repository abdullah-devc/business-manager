// glass.dart
//
// Reusable "liquid glass" surface: a frosted, translucent panel with a
// soft highlight border, meant to sit on top of WaveBackground so the
// wave colors show through, blurred, behind foreground content.
//
// Usage:
//   GlassContainer(
//     padding: const EdgeInsets.all(16),
//     child: Text('Hello'),
//   )
//
// For a full-bleed frosted bar (app bars, bottom bars) use GlassBar,
// which skips the rounded corners/border and just blurs+tints a strip.

import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_background_controller.dart';

/// Wraps [child] in a Theme whose default text/icon colors track the
/// current background brightness, so plain content sitting directly on
/// WaveBackground (list rows, headers — anything with no glass panel
/// behind it) stays readable as the user dims the background.
///
/// Only wrap the parts of a screen that actually sit on bare
/// WaveBackground — e.g. a Scaffold's `body:`. Never wrap dialogs,
/// popup menus, or plain Material `Card`s: those keep their own solid
/// light surface no matter what the background does, so pinning their
/// text dark (which they already get by default) is correct.
class AdaptiveBackgroundText extends StatelessWidget {
  const AdaptiveBackgroundText({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: AppBackgroundController.instance.brightness,
      child: child,
      builder: (context, brightness, child) {
        final Color primary = AppBackgroundController.adaptiveTextColor(brightness);
        final Color secondary = AppBackgroundController.adaptiveSecondaryTextColor(brightness);
        final ThemeData base = Theme.of(context);
        return Theme(
          data: base.copyWith(
            textTheme: base.textTheme.apply(bodyColor: primary, displayColor: primary),
            iconTheme: base.iconTheme.copyWith(color: primary),
            listTileTheme: base.listTileTheme.copyWith(
              textColor: primary,
              iconColor: primary,
              subtitleTextStyle: TextStyle(color: secondary, fontSize: 13),
            ),
          ),
          // Also establishes an explicit DefaultTextStyle/IconTheme (not
          // just a Theme change), same reasoning as AdaptiveGlassText
          // below: plain Text/Icon widgets with no explicit style reach
          // this reliably regardless of any Material ancestor in
          // between, and it gives unstyled text a correct fallback even
          // when a call site can't easily reach a context scoped below
          // this Theme.
          child: DefaultTextStyle.merge(
            style: TextStyle(color: primary),
            child: IconTheme.merge(
              data: IconThemeData(color: primary),
              child: child!,
            ),
          ),
        );
      },
    );
  }
}

/// Pins descendant text/icons back to a fixed, readable dark shade
/// regardless of any [AdaptiveBackgroundText] ancestor. For genuine
/// solid-light surfaces that never sit directly on WaveBackground —
/// plain Material `Card`s, dialogs, popup menus — text should simply
/// stay dark, so use this there. GlassContainer/GlassBar/
/// GlassActionButton use [AdaptiveGlassText] instead, since their
/// translucent tint over WaveBackground does get dark enough at the
/// low end of the brightness slider that pinned-black text stops
/// being readable.
class PinnedDarkText extends StatelessWidget {
  const PinnedDarkText({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        textTheme: base.textTheme.apply(bodyColor: Colors.black87, displayColor: Colors.black87),
        iconTheme: base.iconTheme.copyWith(color: Colors.black87),
        listTileTheme: base.listTileTheme.copyWith(
          textColor: Colors.black87,
          iconColor: Colors.black87,
          subtitleTextStyle: const TextStyle(color: Colors.black54, fontSize: 13),
        ),
      ),
      // Also establishes an explicit DefaultTextStyle/IconTheme, same
      // reasoning as AdaptiveGlassText/AdaptiveBackgroundText above:
      // plain Text/Icon widgets read DefaultTextStyle, not
      // Theme.textTheme, so without this the Theme override above is a
      // no-op whenever PinnedDarkText sits inside an ancestor
      // AdaptiveBackgroundText (which *does* set an explicit
      // DefaultTextStyle) — the ambient adaptive color would keep
      // winning and text/icons here would silently stay whatever color
      // the surrounding dark-mode background chose, even though this
      // widget is a solid light surface. This also matters for
      // dropdown/menu popups: their overlay route captures the
      // InheritedTheme chain (Theme + DefaultTextStyle) from the
      // call-site context, so establishing DefaultTextStyle here is
      // what keeps a DropdownButtonFormField's popup list readable
      // (dark text on its light menu surface) instead of inheriting
      // adaptive light text from an ancestor AdaptiveBackgroundText.
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.black87),
        child: IconTheme.merge(
          data: const IconThemeData(color: Colors.black87),
          child: child,
        ),
      ),
    );
  }
}

/// Keeps descendant text/icons readable on top of a *glass* surface
/// (GlassContainer, GlassBar, GlassActionButton) as the background
/// brightness slider moves. Unlike [PinnedDarkText], this doesn't pin
/// to a single fixed shade — glass panels are lighter than the raw
/// background at any given brightness (thanks to their white tint),
/// but at the dark end of the slider they still get dark enough that
/// fixed black text loses contrast, so this fades toward white past a
/// point further down the range than [AdaptiveBackgroundText] does.
/// Also establishes an explicit [DefaultTextStyle]/[IconTheme] (not
/// just a [Theme] change) so the color reliably reaches descendant
/// `Text`/`Icon` widgets regardless of any `Material` ancestor in
/// between.
class AdaptiveGlassText extends StatelessWidget {
  const AdaptiveGlassText({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: AppBackgroundController.instance.brightness,
      child: child,
      builder: (context, brightness, child) {
        final Color primary = AppBackgroundController.adaptiveGlassTextColor(brightness);
        final Color secondary = AppBackgroundController.adaptiveGlassSecondaryTextColor(brightness);
        final ThemeData base = Theme.of(context);
        return Theme(
          data: base.copyWith(
            textTheme: base.textTheme.apply(bodyColor: primary, displayColor: primary),
            iconTheme: base.iconTheme.copyWith(color: primary),
            listTileTheme: base.listTileTheme.copyWith(
              textColor: primary,
              iconColor: primary,
              subtitleTextStyle: TextStyle(color: secondary, fontSize: 13),
            ),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: primary),
            child: IconTheme.merge(
              data: IconThemeData(color: primary),
              child: child!,
            ),
          ),
        );
      },
    );
  }
}

/// A frosted-glass panel: blurs whatever is behind it, then lays a
/// translucent tint + hairline highlight border on top.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.blur = 18,
    this.tint,
    this.opacity = 0.55,
    this.borderColor,
    this.borderWidth = 1.2,
    this.boxShadow,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;

  /// Blur sigma applied to the content behind this panel.
  final double blur;

  /// Base tint color. Defaults to white, which reads correctly against
  /// the app's white-based WaveBackground; pass a dark color if you
  /// ever place this over a dark surface instead.
  final Color? tint;

  /// Opacity of the tint layer (0-1). Lower = more of the blurred
  /// background shows through.
  final double opacity;

  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? boxShadow;

  /// Optional tap handler; when set, the panel becomes an InkWell so it
  /// gets a ripple like a normal tappable card.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color baseTint = tint ?? Colors.white;

    Widget content = AdaptiveGlassText(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(borderRadius: borderRadius, onTap: onTap, child: content),
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              color: baseTint.withOpacity(opacity),
              borderRadius: borderRadius,
              border: Border.all(
                color: borderColor ?? Colors.white.withOpacity(0.6),
                width: borderWidth,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.18),
                  Colors.white.withOpacity(0.0),
                ],
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// A genuine liquid-glass button: blurs whatever's behind it, then layers
/// a translucent white base, a diagonal specular sheen (the "glossy"
/// streak liquid glass is known for), a bright rim, and — critically —
/// a shadow sitting *outside* the blur clip so it actually shows (a
/// shadow drawn inside a ClipRRect gets clipped away, which is why the
/// first pass looked flat). Drop-in replacement for ElevatedButton —
/// same `onPressed`/`child` shape, plus `GlassButton.icon`.
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.onPressed,
    required Widget this.child,
    this.color,
    this.padding,
  })  : icon = null,
        label = null;

  const GlassButton.icon({
    super.key,
    required this.onPressed,
    required Widget this.icon,
    required Widget this.label,
    this.color,
    this.padding,
  }) : child = null;

  final VoidCallback? onPressed;
  final Widget? child;
  final Widget? icon;
  final Widget? label;

  /// Optional accent tint (defaults to the theme's primary color).
  final Color? color;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final Color accent = color ?? Theme.of(context).colorScheme.primary;
    // Large radius + ClipRRect's own clamping produces a true pill/stadium
    // shape regardless of the button's height.
    final BorderRadius radius = BorderRadius.circular(999);

    final Widget content = child ??
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [icon!, const SizedBox(width: 8), label!],
        );

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      // Outer layer: shadows only. Left un-clipped so the colored glow
      // and contact shadow actually render instead of being cut off.
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            // Colored ambient glow — the "liquid" identity color bleeding
            // softly onto the page behind the button.
            BoxShadow(color: accent.withOpacity(0.35), blurRadius: 20, spreadRadius: -6, offset: const Offset(0, 6)),
            // Neutral contact shadow — lifts the pill off the background
            // so it reads as a distinct floating surface, not a smudge.
            BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                // Bright, mostly-white glass base — a colored tint this
                // pale washes out against a pale background, so white
                // dominates and the accent only shows at the rim/glow.
                color: Colors.white.withOpacity(0.38),
                border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.5),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.45, 1.0],
                  colors: [
                    Colors.white.withOpacity(0.75),
                    Colors.white.withOpacity(0.18),
                    accent.withOpacity(0.16),
                  ],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Thin bright glint along the top rim — the highlight
                  // that catches the "light" and reads as curved glass.
                  Positioned(
                    left: 18,
                    right: 18,
                    top: 2.5,
                    child: Container(
                      height: 1.5,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(1),
                        gradient: LinearGradient(
                          colors: [Colors.white.withOpacity(0), Colors.white.withOpacity(0.95), Colors.white.withOpacity(0)],
                        ),
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: radius,
                      onTap: onPressed,
                      splashColor: accent.withOpacity(0.25),
                      highlightColor: Colors.white.withOpacity(0.25),
                      child: Padding(
                        padding: padding ?? const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                        child: DefaultTextStyle.merge(
                          style: TextStyle(color: accent.darken(), fontWeight: FontWeight.w600, letterSpacing: 0.2),
                          child: IconTheme.merge(
                            data: IconThemeData(color: accent.darken()),
                            child: content,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/// A button styled to match the flat frosted GlassContainer surface used
/// by the dashboard's stat cards (subtle tint, hairline border, soft
/// drop shadow) instead of GlassButton's glossy pill look. Use this for
/// primary form actions and menu-style navigation buttons so the whole
/// app reads as one consistent "glass card" design language.
class GlassActionButton extends StatelessWidget {
  const GlassActionButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.color,
    this.padding,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.expand = false,
  });

  final VoidCallback? onPressed;
  final Widget label;
  final IconData? icon;

  /// Optional accent tint for the icon chip (defaults to the theme's
  /// primary color).
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final BorderRadius borderRadius;

  /// If true, the button stretches to fill the available width instead
  /// of sizing to its content (e.g. a full-width "Save" button in a form
  /// or the "Unlock" button on the login screen).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final Color accent = color ?? Theme.of(context).colorScheme.primary;

    final Widget content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          CircleAvatar(radius: 16, backgroundColor: accent.withOpacity(0.18), child: Icon(icon, color: accent, size: 18)),
          const SizedBox(width: 10),
        ],
        Flexible(
          // Deliberately no `color` here: GlassContainer wraps this in
          // AdaptiveGlassText, and a hard-coded color captured from
          // Theme.of(context) at this point (before that wrap happens)
          // would bake in a fixed shade that shadows the adaptive one
          // and stops the label from ever turning light in dark mode.
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2),
            overflow: TextOverflow.ellipsis,
            child: label,
          ),
        ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GlassContainer(
        borderRadius: borderRadius,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        onTap: onPressed,
        child: content,
      ),
    );
  }
}

/// Returns the appropriate dropdown menu background color based on the
/// current brightness setting. Use this as the `dropdownColor` parameter
/// for DropdownButtonFormField widgets to make their popup menus adapt
/// to the brightness slider.
class AdaptiveDropdownColor extends StatelessWidget {
  const AdaptiveDropdownColor({super.key, required this.builder});

  final Widget Function(BuildContext context, Color dropdownColor) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: AppBackgroundController.instance.brightness,
      builder: (context, brightness, _) {
        // When brightness is low (dark mode), use dark dropdown background
        // When brightness is high (light mode), use white dropdown background
        final isDarkMode = brightness < 0.5;
        final dropdownColor = isDarkMode ? Colors.grey.shade900 : Colors.white;
        return builder(context, dropdownColor);
      },
    );
  }
}

/// A wrapper for DropdownButtonFormField that automatically adapts to the
/// current brightness mode, ensuring both the dropdown button and its menu
/// have appropriate colors.
class AdaptiveDropdownButtonFormField<T> extends StatelessWidget {
  const AdaptiveDropdownButtonFormField({
    super.key,
    required this.items,
    required this.onChanged,
    this.value,
    this.decoration,
    this.validator,
    this.hint,
  });

  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final T? value;
  final InputDecoration? decoration;
  final String? Function(T?)? validator;
  final Widget? hint;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: AppBackgroundController.instance.brightness,
      builder: (context, brightness, _) {
        final isDarkMode = brightness < 0.5;
        final menuBackgroundColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
        final textColor = isDarkMode ? Colors.white : Colors.black87;
        final iconColor = isDarkMode ? Colors.white70 : Colors.black54;
        final dividerColor = isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300;

        // Restyle all menu items to have proper colors
        final styledItems = items.map((item) {
          return DropdownMenuItem<T>(
            value: item.value,
            child: DefaultTextStyle(
              style: TextStyle(color: textColor, fontSize: 14),
              child: item.child,
            ),
          );
        }).toList();

        return Theme(
          data: Theme.of(context).copyWith(
            canvasColor: menuBackgroundColor,
            dividerColor: dividerColor,
            textTheme: Theme.of(context).textTheme.apply(
              bodyColor: textColor,
              displayColor: textColor,
            ),
            iconTheme: IconThemeData(color: iconColor),
            dropdownMenuTheme: DropdownMenuThemeData(
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: menuBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          child: DropdownButtonFormField<T>(
            value: value,
            items: styledItems,
            onChanged: onChanged,
            decoration: decoration,
            validator: validator,
            hint: hint,
            dropdownColor: menuBackgroundColor,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.normal,
            ),
            icon: Icon(Icons.arrow_drop_down, color: iconColor),
            isExpanded: true,
          ),
        );
      },
    );
  }
}

extension _DarkenColor on Color {
  /// Deepens a color for readable text/icons on top of a light glass
  /// tint (plain accent color is often too pale to read well here).
  Color darken([double amount = 0.35]) {
    final hsl = HSLColor.fromColor(this);
    final l = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(l).toColor();
  }
}
/// A full-width frosted strip with no rounding/border — for app bars and
/// bottom bars that need to blur content scrolling underneath them
/// without looking like a floating card.
class GlassBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassBar({
    super.key,
    required this.child,
    this.height = kToolbarHeight,
    this.blur = 20,
    this.tint,
    this.opacity = 0.55,
  });

  final Widget child;
  final double height;
  final double blur;
  final Color? tint;
  final double opacity;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final Color baseTint = tint ?? Colors.white;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: baseTint.withOpacity(opacity),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.5), width: 1),
            ),
          ),
          child: AdaptiveGlassText(child: child),
        ),
      ),
    );
  }
}
