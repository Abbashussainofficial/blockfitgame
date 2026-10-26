import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// A short celebratory message such as "COMBO x3!" or "NEW BEST!".
/// A new [id] restarts the animation even if the text is the same.
class BannerMessage {
  const BannerMessage({
    required this.id,
    required this.lines,
    required this.color,
  });

  final int id;
  final List<String> lines;
  final Color color;
}

/// Pops [message] in over the board, holds it, then floats it up and fades
/// it out. Non-interactive, so it never blocks dragging.
class ScoreBanner extends StatefulWidget {
  const ScoreBanner({super.key, required this.message});

  final BannerMessage? message;

  @override
  State<ScoreBanner> createState() => _ScoreBannerState();
}

class _ScoreBannerState extends State<ScoreBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: UiConfig.bannerDuration,
    value: 1,
  );

  /// Pop in with a slight overshoot, then settle.
  late final Animation<double> _scale = TweenSequence([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.4,
        end: 1.15,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 18,
    ),
    TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 12),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
  ]).animate(_c);

  late final Animation<double> _opacity = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 12),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 58),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
  ]).animate(_c);

  late final Animation<Offset> _slide =
      Tween(begin: Offset.zero, end: const Offset(0, -0.6))
          .chain(
            CurveTween(curve: const Interval(0.7, 1, curve: Curves.easeIn)),
          )
          .animate(_c);

  @override
  void didUpdateWidget(ScoreBanner old) {
    super.didUpdateWidget(old);
    if (widget.message != null && widget.message!.id != old.message?.id) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    if (m == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => _c.value >= 1
            ? const SizedBox.shrink()
            : FractionalTranslation(
                translation: _slide.value,
                child: Opacity(
                  opacity: _opacity.value,
                  child: Transform.scale(scale: _scale.value, child: child),
                ),
              ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Each line stays on one row and shrinks to fit narrow boards.
            for (final line in m.lines)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  line,
                  maxLines: 1,
                  style: TextStyle(
                    color: m.color,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    shadows: const [
                      Shadow(blurRadius: 12, color: Colors.black54),
                      Shadow(offset: Offset(0, 3), color: Colors.black38),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
