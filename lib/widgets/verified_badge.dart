import 'package:flutter/material.dart';

class VerifiedBadge extends StatelessWidget {
  final double size;
  const VerifiedBadge({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Doğrulanmış',
      child: Icon(
        Icons.verified_rounded,
        color: const Color(0xFF673AB7),
        size: size,
      ),
    );
  }
}

extension VerifiedHelper on Map<String, dynamic>? {
  bool get isVerified => this?['is_verified'] == true;
}
