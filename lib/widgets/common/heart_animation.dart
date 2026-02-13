import 'package:flutter/material.dart';

class HeartAnimation extends StatelessWidget {
  final bool show;
  final VoidCallback onEnd;

  const HeartAnimation({
    super.key,
    required this.show,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();

    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.2, end: 1.4),
            duration: const Duration(milliseconds: 1300),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Opacity(
                opacity: (1.4 - value).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: value,
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.redAccent,
                    size: 120,
                  ),
                ),
              );
            },
            onEnd: onEnd,
          ),
        ),
      ),
    );
  }
}
