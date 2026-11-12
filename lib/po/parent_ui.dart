import 'package:flutter/material.dart';

import '../mimigo_design.dart';

/// Six calm dots showing how many PIN digits were typed (never the digits).
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.filled, this.length = 6});
  final int filled, length;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < length; i++)
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? MimiColors.blue : Colors.transparent,
              border: Border.all(color: MimiColors.blue, width: 2),
            ),
          ),
      ],
    ),
  );
}
