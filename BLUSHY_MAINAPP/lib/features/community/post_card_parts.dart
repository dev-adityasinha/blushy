import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/scale.dart';

/// The pieces a post card is made of, shared by the feed and the discussion
/// page so the two cannot drift apart.
///
/// Presentation only: what a tag, an avatar and an action look like. What
/// they do is passed in by the screen that has the data and the handlers.

/// The letter-in-a-circle that stands in for a profile picture.
class PostAvatar extends StatelessWidget {
  const PostAvatar({super.key, required this.name, this.onTap});

  final String name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: BlushySpace.tile,
      height: BlushySpace.tile,
      decoration: BoxDecoration(
        color: BlushyColors.primary.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: BlushyType.heading(
          color: BlushyColors.primary,
          weight: FontWeight.w700,
        ),
      ),
    );
    if (onTap == null) return avatar;
    return GestureDetector(onTap: onTap, child: avatar);
  }
}

/// The name and, under it, when the post was made.
class PostByline extends StatelessWidget {
  const PostByline({
    super.key,
    required this.name,
    required this.timeAgo,
    this.onTap,
  });

  final String name;
  final String timeAgo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Text(name, style: BlushyType.heading()),
        ),
        Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 11, color: BlushyColors.secondaryText),
            const SizedBox(width: BlushySpace.xs),
            Text(timeAgo, style: BlushyType.caption()),
          ],
        ),
      ],
    );
  }
}

/// A tag on a post.
class PostTagPill extends StatelessWidget {
  const PostTagPill(this.tag, {super.key});

  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: BlushySpace.md, vertical: BlushySpace.xs + 2),
      decoration: BoxDecoration(
        color: BlushyColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        tag,
        style: BlushyType.caption(
          color: BlushyColors.primary,
          weight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// One control on a post's footer.
///
/// Tinted where it is the one that matters most (the like), outlined
/// otherwise. A count beside the icon where there is one.
class PostActionPill extends StatelessWidget {
  const PostActionPill({
    super.key,
    required this.icon,
    this.onTap,
    this.label,
    this.tinted = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? label;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final color = tinted ? BlushyColors.primary : BlushyColors.text;

    return Material(
      color: tinted
          ? BlushyColors.primary.withValues(alpha: 0.08)
          : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: BlushySpace.tapHeight,
          padding: const EdgeInsets.symmetric(horizontal: BlushySpace.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: tinted ? null : Border.all(color: BlushyColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              if (label != null) ...[
                const SizedBox(width: BlushySpace.xs + 2),
                Text(
                  label!,
                  style: BlushyType.body(color: color, weight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
