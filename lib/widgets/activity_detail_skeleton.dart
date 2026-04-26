import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ActivityDetailSkeleton extends StatelessWidget {
  const ActivityDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF616161) : const Color(0xFFE0E0E0);
    final highlight = isDark ? const Color(0xFF9E9E9E) : const Color(0xFFF5F5F5);

    return ExcludeSemantics(
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        period: const Duration(milliseconds: 1500),
        direction: ShimmerDirection.ltr,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(color: Colors.white),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 24, width: double.infinity, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(height: 20, width: 200, color: Colors.white),
                    const SizedBox(height: 20),
                    _row(context, 0.7),
                    const SizedBox(height: 10),
                    _row(context, 0.55),
                    const SizedBox(height: 20),
                    Container(height: 14, width: double.infinity, color: Colors.white),
                    const SizedBox(height: 6),
                    Container(height: 14, width: double.infinity, color: Colors.white),
                    const SizedBox(height: 6),
                    Container(height: 14, width: MediaQuery.sizeOf(context).width * 0.6, color: Colors.white),
                    const SizedBox(height: 24),
                    Container(height: 18, width: 120, color: Colors.white),
                    const SizedBox(height: 12),
                    _participantRow(),
                    const SizedBox(height: 10),
                    _participantRow(),
                    const SizedBox(height: 10),
                    _participantRow(),
                    const SizedBox(height: 10),
                    _participantRow(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, double widthFraction) {
    return Row(
      children: [
        Container(width: 20, height: 20, color: Colors.white),
        const SizedBox(width: 8),
        Container(
          height: 14,
          width: MediaQuery.sizeOf(context).width * widthFraction,
          color: Colors.white,
        ),
      ],
    );
  }

  Widget _participantRow() {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Container(height: 14, width: 120, color: Colors.white),
      ],
    );
  }
}
