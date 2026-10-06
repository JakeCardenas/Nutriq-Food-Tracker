import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../app/theme.dart';

/// Motion constants in Apple's terms (response + damping ratio), shared by the
/// sheet and other gesture-driven surfaces.
abstract final class NqMotion {
  /// Critically damped: settles without overshoot (opening, settling back).
  static final SpringDescription settle = spring(response: 0.34, dampingRatio: 1.0);

  /// Stiffness for a spring that settles in roughly [response] seconds.
  static SpringDescription spring({required double response, required double dampingRatio}) =>
      SpringDescription.withDampingRatio(
        mass: 1,
        stiffness: math.pow(2 * math.pi / response, 2).toDouble(),
        ratio: dampingRatio,
      );

  /// Natural frequency of [settle], used to cap hand-off velocity so a
  /// critically damped settle never crosses its target.
  static double get settleOmega => 2 * math.pi / 0.34;

  /// How far a release velocity carries (px), using the deceleration iOS uses
  /// for scrolling — a flick "throws" the sheet rather than snapping from where
  /// the finger let go.
  static double project(double velocity, {double decelerationRate = 0.998}) =>
      velocity / 1000 * decelerationRate / (1 - decelerationRate);

  /// Progressive resistance past an edge: the further past, the less it follows.
  static double rubberBand(double overshoot, double dimension, {double constant = 0.55}) =>
      dimension <= 0 ? 0 : overshoot * dimension * constant / (dimension + constant * overshoot.abs());
}

/// A critically damped spring as a [Curve], for transitions that aren't
/// driven by a finger (menus, small reveals). Fast out of the gate, eases into
/// rest, never overshoots; normalised so it lands exactly on 1.
class NqSpringCurve extends Curve {
  const NqSpringCurve({this.response = 0.34, this.seconds = 0.42});

  /// Spring response (s) and the transition length it is laid out over.
  final double response;
  final double seconds;

  double _position(double time) {
    final omega = 2 * math.pi / response;
    return 1 - (1 + omega * time) * math.exp(-omega * time);
  }

  @override
  double transformInternal(double t) => _position(t * seconds) / _position(seconds);
}

/// Something a scroll view inside a sheet can hand its drag to.
abstract interface class SheetDragTarget {
  /// True while the sheet is pulled away from its resting position (or still
  /// opening): content drags move the sheet, not the content.
  bool get displaced;

  /// Moves the sheet by a finger delta (down is positive).
  void dragBy(double dy, {bool fromContent = false});

  /// The finger lifted after the content dragged the sheet. Returns true when
  /// the sheet took the gesture's momentum (so the content must not fling).
  bool takeRelease(double velocityDown);
}

/// Scroll physics for content inside an [NqSheetRoute]: when the content is at
/// its top, pulling down drags the sheet (the iOS sheet behaviour); while the
/// sheet is displaced, moving back up returns the sheet before scrolling.
class SheetScrollPhysics extends ScrollPhysics {
  const SheetScrollPhysics(this.target, {super.parent});

  final SheetDragTarget target;

  @override
  SheetScrollPhysics applyTo(ScrollPhysics? ancestor) => SheetScrollPhysics(target, parent: buildParent(ancestor));

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (position.axis == Axis.vertical) {
      final atTop = position.pixels <= position.minScrollExtent + 0.5;
      if (target.displaced || (atTop && offset > 0)) {
        target.dragBy(offset, fromContent: true);
        return 0;
      }
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    // Scroll velocity is positive when content moves up, i.e. the finger moves up.
    if (target.takeRelease(-velocity)) return null;
    return super.createBallisticSimulation(position, velocity);
  }
}

/// Gives scroll views inside a sheet the [SheetScrollPhysics] that cooperate
/// with the sheet's drag.
class NqSheetScope extends InheritedWidget {
  const NqSheetScope({super.key, required this.target, required super.child});

  final SheetDragTarget target;

  /// Physics for a vertical scroll view in the nearest sheet, or null outside one.
  static ScrollPhysics? physicsOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<NqSheetScope>();
    return scope == null ? null : SheetScrollPhysics(scope.target);
  }

  @override
  bool updateShouldNotify(NqSheetScope oldWidget) => oldWidget.target != target;
}

/// A bottom sheet whose motion is driven by the finger and by springs:
///
/// - It tracks the finger 1:1 and can be grabbed mid-animation.
/// - On release, the momentum is projected forward. A flick or a drag
///   past half dismisses it with the finger's velocity; otherwise it
///   settles back with a critically damped spring (no bounce).
/// - Dragging up past fully open rubber-bands.
/// - With Reduce Motion it cross-fades in place, and a swipe down still
///   closes it.
class NqSheetRoute<T> extends PopupRoute<T> {
  NqSheetRoute({
    required this.builder,
    required this.barrierLabel,
    this.dismissible = true,
    this.reduceMotion = false,
    super.settings,
  });

  final WidgetBuilder builder;
  final bool dismissible;
  final bool reduceMotion;

  @override
  final String? barrierLabel;

  @override
  Color get barrierColor => const Color(0x66000000);

  @override
  bool get barrierDismissible => dismissible;

  // Used only for the Reduce Motion cross-fade; springs drive everything else.
  @override
  Duration get transitionDuration => const Duration(milliseconds: 180);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 150);

  /// Velocity (sheet heights per second) handed over by a drag that ends in a dismissal.
  double _handoffVelocity = 0;

  AnimationController get _progress => controller!;

  @override
  Simulation? createSimulation({required bool forward}) {
    if (reduceMotion) return null;
    final velocity = _handoffVelocity;
    _handoffVelocity = 0;
    final from = _progress.value;
    return forward
        ? SpringSimulation(NqMotion.settle, from, 1, 0)
        : _UntilReached(SpringSimulation(NqMotion.settle, from, 0, velocity), target: 0);
  }

  void _dismissWithVelocity(double velocity) {
    if (!isActive) return;
    _handoffVelocity = velocity;
    if (isCurrent) {
      navigator!.pop();
    } else {
      navigator!.removeRoute(this);
    }
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      _SheetFrame(
        route: this,
        child: Builder(builder: builder),
      );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => reduceMotion ? FadeTransition(opacity: animation, child: child) : child;
}

/// Ends a closing spring as soon as the sheet is off screen, so the route is
/// removed without waiting for an invisible tail.
class _UntilReached extends Simulation {
  _UntilReached(this.inner, {required this.target});

  final Simulation inner;
  final double target;

  @override
  double x(double time) => inner.x(time);

  @override
  double dx(double time) => inner.dx(time);

  @override
  bool isDone(double time) => inner.isDone(time) || inner.x(time) <= target + 0.0005;
}

class _SheetFrame extends StatefulWidget {
  const _SheetFrame({required this.route, required this.child});

  final NqSheetRoute<dynamic> route;
  final Widget child;

  @override
  State<_SheetFrame> createState() => _SheetFrameState();
}

class _SheetFrameState extends State<_SheetFrame> with SingleTickerProviderStateMixin implements SheetDragTarget {
  final _surfaceKey = GlobalKey();

  /// Rubber-band offset in px beyond the resting edge (up is positive).
  late final AnimationController _lift = AnimationController.unbounded(vsync: this);

  /// Finger distance beyond the edge, before resistance is applied.
  double _beyond = 0;

  /// The current gesture moved the sheet through a scroll view.
  bool _contentDragged = false;

  /// Reduce Motion: the sheet stays put; this counts how far the finger swiped.
  double _reducedSwipe = 0;

  NqSheetRoute<dynamic> get _route => widget.route;
  AnimationController get _progress => _route._progress;
  double get _height => _surfaceKey.currentContext?.size?.height ?? 0;

  @override
  void dispose() {
    _lift.dispose();
    super.dispose();
  }

  @override
  bool get displaced => !_route.reduceMotion && (_progress.value < 0.9995 || _lift.value.abs() > 0.5);

  void _grab() {
    if (!_route.isActive) return;
    _progress.stop();
    _lift.stop();
    _beyond = SheetDragTargetMath.inverseRubberBand(_lift.value, _height);
    _reducedSwipe = 0;
  }

  @override
  void dragBy(double dy, {bool fromContent = false}) {
    if (!_route.isActive) return;
    if (fromContent) _contentDragged = true;
    if (_route.reduceMotion) {
      _reducedSwipe += dy;
      return;
    }
    final height = _height;
    if (height <= 0) return;
    if (_progress.isAnimating) _progress.stop();
    if (_lift.isAnimating) _lift.stop();

    var remaining = dy;
    // Moving back toward rest first undoes any stretch beyond the edge.
    if (_beyond > 0 && remaining > 0) {
      final take = math.min(_beyond, remaining);
      _beyond -= take;
      remaining -= take;
    } else if (_beyond < 0 && remaining < 0) {
      final take = math.max(_beyond, remaining);
      _beyond -= take;
      remaining -= take;
    }
    // Then the sheet itself follows the finger.
    if (remaining != 0 && _route.dismissible) {
      final next = _progress.value - remaining / height;
      if (next > 1) {
        _progress.value = 1;
        remaining = -(next - 1) * height;
      } else {
        _progress.value = math.max(0, next);
        remaining = 0;
      }
    }
    // Whatever is left stretches past the edge, with resistance. Content
    // drags stop at fully open so the content can scroll instead.
    if (remaining != 0 && !(fromContent && remaining < 0)) {
      _beyond -= remaining;
    }
    _lift.value = NqMotion.rubberBand(_beyond, height);
  }

  @override
  bool takeRelease(double velocityDown) {
    if (!_contentDragged) return false;
    _release(velocityDown);
    return true;
  }

  void _release(double velocityDown) {
    _contentDragged = false;
    if (!_route.isActive) return;
    if (_route.reduceMotion) {
      final swipe = _reducedSwipe;
      _reducedSwipe = 0;
      if (_route.dismissible && (swipe > 120 || velocityDown > 900)) _route._dismissWithVelocity(0);
      return;
    }
    final height = _height;
    if (height <= 0) return;

    // Stretched past the edge: spring back, carrying the finger's velocity.
    if (_beyond != 0) {
      _beyond = 0;
      _lift.animateWith(SpringSimulation(NqMotion.settle, _lift.value, 0, -velocityDown));
    }
    final value = _progress.value;
    if (value >= 1) return;

    final projected = value - NqMotion.project(velocityDown) / height;
    if (_route.dismissible && (velocityDown > 900 || projected < 0.5)) {
      _route._dismissWithVelocity(-velocityDown / height);
      return;
    }
    // Settle open. Cap the upward hand-off so the critically damped spring
    // arrives without crossing the top (which would end in a hard stop).
    final velocity = math.min(-velocityDown / height, NqMotion.settleOmega * (1 - value));
    _progress.animateWith(SpringSimulation(NqMotion.settle, value, 1, velocity));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height - media.padding.top - 8;
    return NqSheetScope(
      target: this,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedBuilder(
          animation: Listenable.merge([_progress, _lift]),
          builder: (context, child) => FractionalTranslation(
            translation: Offset(0, _route.reduceMotion ? 0 : 1 - _progress.value),
            child: Transform.translate(offset: Offset(0, -_lift.value), child: child),
          ),
          child: GestureDetector(
            onVerticalDragStart: (_) => _grab(),
            onVerticalDragUpdate: (d) => dragBy(d.delta.dy),
            onVerticalDragEnd: (d) => _release(d.velocity.pixelsPerSecond.dy),
            onVerticalDragCancel: () => _release(0),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: _SheetSurface(key: _surfaceKey, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Converts a displayed rubber-band offset back to finger distance, so a sheet
/// grabbed while springing back continues from where it is.
abstract final class SheetDragTargetMath {
  static double inverseRubberBand(double offset, double dimension, {double constant = 0.55}) {
    if (dimension <= 0 || offset == 0) return 0;
    // offset = x·d·c / (d + c·|x|)  ⇒  |x| = |offset|·d / (c·d − c·|offset|)
    final denominator = constant * dimension - constant * offset.abs();
    if (denominator <= 0) return offset;
    return offset.sign * offset.abs() * dimension / denominator;
  }
}

/// White rounded surface with a grab handle. A strip of the same colour hangs
/// below it so a rubber-banded sheet never shows a gap at the bottom.
class _SheetSurface extends StatelessWidget {
  const _SheetSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      const Positioned(
        left: 0,
        right: 0,
        top: 40,
        bottom: -400,
        child: IgnorePointer(child: ColoredBox(color: NqColors.card)),
      ),
      Material(
        color: NqColors.card,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                label: 'Drag down to close',
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(0, 10, 0, 14),
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: NqColors.textTertiary.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    ],
  );
}
