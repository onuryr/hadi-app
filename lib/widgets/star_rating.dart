import 'package:flutter/material.dart';

class StarRating extends StatelessWidget {
  final int value;
  final int max;
  final double size;
  final void Function(int)? onChanged;
  final Color color;

  const StarRating({
    super.key,
    required this.value,
    this.max = 5,
    this.size = 28,
    this.onChanged,
    this.color = Colors.amber,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(max, (i) {
        final filled = i < value;
        return GestureDetector(
          onTap: onChanged == null ? null : () => onChanged!(i + 1),
          child: Icon(
            filled ? Icons.star : Icons.star_border,
            color: filled ? color : Colors.grey,
            size: size,
          ),
        );
      }),
    );
  }
}
