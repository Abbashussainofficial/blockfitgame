import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// Shows [value] and counts up (or down) to each new value.
class AnimatedScore extends StatelessWidget {
  const AnimatedScore({super.key, required this.value, required this.style});

  final int value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    // `begin` only matters on first build; afterwards the builder animates
    // from whatever is on screen to the new `end`.
    tween: Tween(begin: value.toDouble(), end: value.toDouble()),
    duration: UiConfig.scoreCountDuration,
    curve: Curves.easeOutCubic,
    builder: (context, v, _) => Text('${v.round()}', style: style),
  );
}

/// "+N" text that rises from where a piece landed and fades out.
class PointsPopup {
  const PointsPopup({
    required this.id,
    required this.points,
    required this.alignment,
  });

  final int id;
  final int points;

  /// Position over the board (-1..1 on each axis).
  final Alignment alignment;
}

class FloatingPoints extends StatelessWidget {
  const FloatingPoints({super.key, required this.popup, required this.color});

  final PointsPopup popup;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Align(
      alignment: popup.alignment,
      child: TweenAnimationBuilder<double>(
        // Keyed by id in the parent, so each popup animates from 0.
        tween: Tween(begin: 0, end: 1),
        duration: UiConfig.pointsPopupDuration,
        builder: (context, t, child) => t >= 1
            ? const SizedBox.shrink()
            : Transform.translate(
                offset: Offset(0, -40 * Curves.easeOut.transform(t)),
                child: Opacity(
                  opacity: t < 0.6 ? 1 : (1 - t) / 0.4,
                  child: Transform.scale(
                    scale:
                        0.8 +
                        0.2 *
                            Curves.easeOutBack.transform(t.clamp(0, 0.4) / 0.4),
                    child: child,
                  ),
                ),
              ),
        child: Text(
          '+${popup.points}',
          style: TextStyle(
            color: color,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            shadows: const [Shadow(blurRadius: 8, color: Colors.black45)],
          ),
        ),
      ),
    ),
  );
}

/// Scales its child in from nothing the first time it is built. Give it a
/// new key to replay (e.g. per tray piece id).
class PopIn extends StatefulWidget {
  const PopIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  // The delay is part of the animation (an Interval), so no timers are left
  // running if the widget goes away early.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: UiConfig.trayPopDuration + widget.delay,
  )..forward();
  late final Animation<double> _scale = CurvedAnimation(
    parent: _c,
    curve: Interval(
      widget.delay.inMicroseconds / _c.duration!.inMicroseconds,
      1,
      curve: Curves.easeOutBack,
    ),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}
