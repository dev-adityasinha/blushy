import 'package:flutter/material.dart';

/// Docsy's face, as the brand artwork draws it.
///
/// This was 360 lines of hand-written `CustomPainter` path data trying to
/// reproduce the reference drawing from memory -- the eyebrows were missing
/// entirely and the hair silhouette came out lumpy. It is now the artwork
/// itself, at `assets/docsy_icon.png`.
///
/// The asset is a single-colour alpha shape: every pixel is the brand red and
/// the drawing lives in the alpha channel, with the face left transparent so
/// it takes the surface behind it. That is what lets one file serve both the
/// active tab (brand red) and the inactive one (grey) -- [color] is applied
/// with `BlendMode.srcIn`, which repaints the shape and keeps its edges.
class DocsyAvatar extends StatelessWidget {
  final double size;
  final Color color;
  final Color backgroundColor;
  final bool hasBackground;

  const DocsyAvatar({
    super.key,
    this.size = 32,
    this.color = const Color(0xFFDD0D22),
    this.backgroundColor = Colors.transparent,
    this.hasBackground = false,
  });

  /// The artwork. One asset, tinted at each call site.
  static const String assetPath = 'assets/docsy_icon.png';

  @override
  Widget build(BuildContext context) {
    final Widget avatar = Image.asset(
      assetPath,
      width: size,
      height: size,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      fit: BoxFit.contain,
      // Named for screen readers at every size; the face carries no text.
      semanticLabel: 'Docsy',
      // A tab icon is never the reason a screen fails to draw.
      errorBuilder: (context, error, stack) => Icon(
        Icons.face_retouching_natural_outlined,
        size: size,
        color: color,
      ),
    );

    if (hasBackground) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor == Colors.transparent
              ? color.withValues(alpha: 0.12)
              : backgroundColor,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: SizedBox(
          width: size * 0.78,
          height: size * 0.78,
          child: Image.asset(
            assetPath,
            color: color,
            colorBlendMode: BlendMode.srcIn,
            fit: BoxFit.contain,
            semanticLabel: 'Docsy',
            errorBuilder: (context, error, stack) => Icon(
              Icons.face_retouching_natural_outlined,
              size: size * 0.78,
              color: color,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: avatar,
    );
  }
}

/// Docsy Icon: Drop-in scalable icon widget
class DocsyIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final Color backgroundColor;

  const DocsyIcon({
    super.key,
    this.size = 24,
    this.color,
    this.backgroundColor = Colors.transparent,
  });

  @override
  Widget build(BuildContext context) {
    final IconThemeData iconTheme = IconTheme.of(context);
    final Color effectiveColor = color ?? iconTheme.color ?? const Color(0xFFDD0D22);

    return DocsyAvatar(
      size: size,
      color: effectiveColor,
      backgroundColor: backgroundColor,
      hasBackground: false,
    );
  }
}
