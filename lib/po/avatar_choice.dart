import 'package:flutter/material.dart';

import '../mimigo_design.dart';

/// Predefined child avatars (stock keys are the server contract; the look is drawn in code).
class AvatarOption {
  const AvatarOption(this.key, this.name, this.icon, this.color, this.onColor);
  final String key, name;
  final IconData icon;
  final Color color, onColor;
}

const childAvatarOptions = <AvatarOption>[
  AvatarOption(
    'bear-blue',
    'Gấu xanh',
    Icons.pets_rounded,
    MimiColors.blue,
    Colors.white,
  ),
  AvatarOption(
    'bee-yellow',
    'Ong vàng',
    Icons.emoji_nature_rounded,
    Color(0xFFFFD133),
    MimiColors.ink,
  ),
];

AvatarOption? avatarOptionFor(String? key) {
  for (final o in childAvatarOptions) {
    if (o.key == key) return o;
  }
  return null;
}

/// A solid colour disc with a clear white/ink glyph. Unknown keys fall back to a neutral child icon.
class AvatarBadge extends StatelessWidget {
  const AvatarBadge({super.key, required this.stockKey, this.size = 44});
  final String? stockKey;
  final double size;
  @override
  Widget build(BuildContext context) {
    final o = avatarOptionFor(stockKey);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: o?.color ?? MimiColors.sky,
        ),
        child: Icon(
          o?.icon ?? Icons.child_care_rounded,
          color: o?.onColor ?? MimiColors.ink,
          size: size * .56,
        ),
      ),
    );
  }
}
