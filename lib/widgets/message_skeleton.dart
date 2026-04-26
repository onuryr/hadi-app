import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';

class MessageSkeleton extends StatelessWidget {
  const MessageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      excluding: true,
      child: Shimmer.fromColors(
        baseColor: AppColors.shimmerBase,
        highlightColor: AppColors.shimmerHighlight,
        period: const Duration(milliseconds: 1500),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _incomingRow(120),
              const SizedBox(height: 12),
              _outgoingRow(160),
              const SizedBox(height: 12),
              _incomingRow(200),
              const SizedBox(height: 12),
              _outgoingRow(100),
              const SizedBox(height: 12),
              _incomingRow(140),
            ],
          ),
        ),
      ),
    );
  }

  Widget _incomingRow(double bubbleWidth) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Container(
          width: bubbleWidth,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ],
    );
  }

  Widget _outgoingRow(double bubbleWidth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: bubbleWidth,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ],
    );
  }
}
