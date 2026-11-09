import 'package:flutter/material.dart';

/// Opaque surface for readable content (messages, posts, settings rows).
///
/// Do not wrap this in glass widgets — content must stay legible.
class OpaqueContentSurface extends StatelessWidget {
  const OpaqueContentSurface({
    required this.child,
    super.key,
    this.padding,
    this.borderRadius = 16,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
  }
}
