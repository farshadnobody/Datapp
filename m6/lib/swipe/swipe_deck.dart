import 'dart:math' as math;
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'swipe_style.dart';

enum SwipeDirection { left, right, up }

/// میزان «پر شدن» هر دکمه (۰ تا ۱) بر اساس مسیر کشیدن کارت. دکمه‌های پایین
/// این رو گوش می‌دن تا همزمان با کشیدن کارت پر بشن (مثل تیندر).
class SwipeProgress {
  final double like;
  final double pass;
  final double superLike;
  const SwipeProgress(this.like, this.pass, this.superLike);

  static const SwipeProgress zero = SwipeProgress(0, 0, 0);

  SwipeProgress scaled(double f) => SwipeProgress(like * f, pass * f, superLike * f);

  @override
  bool operator ==(Object other) =>
      other is SwipeProgress &&
      other.like == like &&
      other.pass == pass &&
      other.superLike == superLike;

  @override
  int get hashCode => Object.hash(like, pass, superLike);
}

/// کنترلر بیرونیِ Deck: دکمه‌ها با این کارت رو پرت می‌کنن، و progress رو
/// برای پر شدن دکمه‌ها می‌دن.
class SwipeDeckController {
  final ValueNotifier<SwipeProgress> progress =
      ValueNotifier<SwipeProgress>(SwipeProgress.zero);

  _SwipeDeckState<dynamic>? _state;
  SwipeDirection? _pendingRewind;

  /// کارت بالا رو با انیمیشن به یه سمت پرت می‌کنه (برای دکمه‌ها).
  void swipe(SwipeDirection direction) => _state?._flyOut(direction);

  /// قبل از این‌که کارت قبلی رو به ابتدای لیست برگردونی صدا بزن؛ Deck کارت
  /// جدید رو از همون سمتی که رفته بود با فنر برمی‌گردونه.
  void prepareRewind(SwipeDirection from) => _pendingRewind = from;

  bool get isFlying => _state?._mode == _Mode.flying;

  void dispose() => progress.dispose();
}

enum _Mode { idle, dragging, returning, flying }

class SwipeDeck<T> extends StatefulWidget {
  final List<T> items;
  final SwipeDeckController controller;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final void Function(T item, SwipeDirection direction) onSwiped;

  /// اگه false باشه کشیدن به بالا (سوپرلایک) کار نمی‌کنه (حالت ۱).
  final bool superLikeEnabled;

  /// اگه false برگردونه، کارت به جای پرت شدن به جاش برمی‌گرده و `onBlocked`
  /// صدا زده می‌شه (مثلاً «قبلاً سوپرلایکش کردی»).
  final bool Function(T item, SwipeDirection direction)? canSwipe;
  final void Function(T item, SwipeDirection direction)? onBlocked;

  const SwipeDeck({
    super.key,
    required this.items,
    required this.controller,
    required this.itemBuilder,
    required this.onSwiped,
    this.superLikeEnabled = false,
    this.canSwipe,
    this.onBlocked,
  });

  @override
  State<SwipeDeck<T>> createState() => _SwipeDeckState<T>();
}

class _SwipeDeckState<T> extends State<SwipeDeck<T>>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  _Mode _mode = _Mode.idle;

  Offset _pos = Offset.zero;
  Offset _vel = Offset.zero;
  double _angle = 0;
  double _angleVel = 0;

  /// نقطه‌ای که کاربر کارت رو گرفته، نسبت به مرکز کارت (بین -۱ و ۱).
  Offset _grab = const Offset(0, -0.6);
  Size _size = Size.zero;

  SwipeDirection? _flyDir;
  double _flyAngleTarget = 0;
  bool _crossed = false;

  // محو شدن تدریجی پر بودن دکمه‌ها بعد از این‌که کارت رفت.
  double _decayT = 0;
  SwipeProgress _decayBase = SwipeProgress.zero;

  Widget? _topCache;
  Widget? _secondCache;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    widget.controller._state = this;
  }

  @override
  void didUpdateWidget(covariant SwipeDeck<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller._state = null;
      widget.controller._state = this;
    }
    _topCache = null;
    _secondCache = null;

    final T? oldTop = oldWidget.items.isNotEmpty ? oldWidget.items.first : null;
    final T? newTop = widget.items.isNotEmpty ? widget.items.first : null;
    if (oldTop != newTop) {
      final rewind = widget.controller._pendingRewind;
      widget.controller._pendingRewind = null;
      if (rewind != null && newTop != null) {
        // کارت از بیرون صفحه، از همون سمتی که رفته بود، با فنر برمی‌گرده.
        final w = _size.width == 0 ? 360.0 : _size.width;
        final h = _size.height == 0 ? 600.0 : _size.height;
        switch (rewind) {
          case SwipeDirection.right:
            _pos = Offset(w * 1.15, 0);
            _angle = 0.35;
            break;
          case SwipeDirection.left:
            _pos = Offset(-w * 1.15, 0);
            _angle = -0.35;
            break;
          case SwipeDirection.up:
            _pos = Offset(0, -h * 1.1);
            _angle = 0;
            break;
        }
        _vel = Offset.zero;
        _angleVel = 0;
        _mode = _Mode.returning;
        _decayT = 0;
        _startTicker();
      } else {
        _resetMotion();
      }
    }
  }

  @override
  void dispose() {
    if (identical(widget.controller._state, this)) {
      widget.controller._state = null;
    }
    _ticker.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // فیزیک
  // ---------------------------------------------------------------------

  void _startTicker() {
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _resetMotion() {
    _pos = Offset.zero;
    _vel = Offset.zero;
    _angle = 0;
    _angleVel = 0;
    _mode = _Mode.idle;
    _flyDir = null;
    _crossed = false;
  }

  void _onTick(Duration elapsed) {
    var dt = (elapsed - _last).inMicroseconds / 1000000.0;
    _last = elapsed;
    if (dt <= 0) return;
    dt = math.min(dt, 1 / 30);

    if (_mode == _Mode.returning) {
      _stepReturn(dt);
    } else if (_mode == _Mode.flying) {
      _stepFly(dt);
    }

    if (_decayT > 0) {
      _decayT -= dt * 6;
      if (_decayT <= 0) {
        _decayT = 0;
        widget.controller.progress.value = SwipeProgress.zero;
      } else {
        widget.controller.progress.value = _decayBase.scaled(_decayT);
      }
    }

    if (_mode == _Mode.idle && _decayT == 0) {
      _ticker.stop();
    }
  }

  void _stepReturn(double dt) {
    // فنر کمی کم‌میرا → حس «شناور» بودن کارت.
    const double k = 260;
    const double c = 20;
    const int steps = 2;
    final double h = dt / steps;
    for (int i = 0; i < steps; i++) {
      final ax = -k * _pos.dx - c * _vel.dx;
      final ay = -k * _pos.dy - c * _vel.dy;
      _vel = Offset(_vel.dx + ax * h, _vel.dy + ay * h);
      _pos = Offset(_pos.dx + _vel.dx * h, _pos.dy + _vel.dy * h);

      final aa = -k * _angle - c * _angleVel;
      _angleVel += aa * h;
      _angle += _angleVel * h;
    }
    if (_pos.distance < 0.4 &&
        _vel.distance < 4 &&
        _angle.abs() < 0.002 &&
        _angleVel.abs() < 0.02) {
      _resetMotion();
    }
    setState(() {});
    _publish();
  }

  void _stepFly(double dt) {
    // کمی شتاب می‌گیره تا خروج تند و طبیعی باشه.
    final accel = 1 + 2.2 * dt;
    _vel = Offset(_vel.dx * accel, _vel.dy * accel);
    _pos = Offset(_pos.dx + _vel.dx * dt, _pos.dy + _vel.dy * dt);
    _angle += (_flyAngleTarget - _angle) * math.min(1.0, dt * 6);
    setState(() {});
    _publish();

    final w = _size.width;
    final h = _size.height;
    final gone = _pos.dx.abs() > w * 1.2 || _pos.dy < -h * 1.1 || _pos.dy > h * 1.1;
    if (gone) _finishFly();
  }

  void _finishFly() {
    final dir = _flyDir;
    final T? item = widget.items.isNotEmpty ? widget.items.first : null;
    _decayBase = _computeProgress();
    _decayT = 1;
    _resetMotion();
    setState(() {});
    if (dir != null && item != null) {
      widget.onSwiped(item, dir);
    }
  }

  // ---------------------------------------------------------------------
  // progress
  // ---------------------------------------------------------------------

  double get _commitX => _size.width * 0.3;
  static const double _commitUp = 100;

  SwipeProgress _computeProgress() {
    if (_size.width == 0) return SwipeProgress.zero;
    final dx = _pos.dx;
    final dy = _pos.dy;
    double like = 0, pass = 0, sup = 0;
    final verticalDominant =
        widget.superLikeEnabled && dy < 0 && -dy > dx.abs();
    if (verticalDominant) {
      sup = (-dy / _commitUp).clamp(0.0, 1.0).toDouble();
    } else {
      if (dx > 0) like = (dx / _commitX).clamp(0.0, 1.0).toDouble();
      if (dx < 0) pass = (-dx / _commitX).clamp(0.0, 1.0).toDouble();
    }
    return SwipeProgress(like, pass, sup);
  }

  void _publish() {
    widget.controller.progress.value = _computeProgress();
  }

  // ---------------------------------------------------------------------
  // ژست‌ها
  // ---------------------------------------------------------------------

  void _onPanStart(DragStartDetails d) {
    if (_mode == _Mode.flying || widget.items.isEmpty) return;
    _decayT = 0;
    _mode = _Mode.dragging;
    _crossed = false;
    _vel = Offset.zero;
    _angleVel = 0;

    final cx = _size.width / 2;
    final cy = _size.height / 2;
    final double rx = ((d.localPosition.dx - cx) / cx).clamp(-1.0, 1.0).toDouble();
    double ry = ((d.localPosition.dy - cy) / cy).clamp(-1.0, 1.0).toDouble();
    // حداقل کج شدن، حتی وقتی وسط کارت رو می‌گیری.
    if (ry.abs() < 0.35) ry = ry > 0 ? 0.35 : -0.35;
    _grab = Offset(rx, ry);
  }

  double _angleFor(Offset p) {
    final w = _size.width == 0 ? 360.0 : _size.width;
    // ممان نیرو: اگه کارت رو از بالا بگیری و به راست بکشی، بالاش بیشتر
    // می‌ره راست؛ اگه از پایین بگیری، پایینش.
    final raw = 0.6 * (-_grab.dy * p.dx + 0.3 * _grab.dx * p.dy) / w;
    return raw.clamp(-0.55, 0.55).toDouble();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_mode != _Mode.dragging) return;
    _pos = _pos + d.delta;
    _angle = _angleFor(_pos);

    final over = _pos.dx.abs() > _commitX ||
        (widget.superLikeEnabled && -_pos.dy > _commitUp && -_pos.dy > _pos.dx.abs());
    if (over && !_crossed) HapticFeedback.selectionClick();
    _crossed = over;

    setState(() {});
    _publish();
  }

  void _onPanEnd(DragEndDetails d) {
    if (_mode != _Mode.dragging) return;
    final v = d.velocity.pixelsPerSecond;
    final dx = _pos.dx;
    final dy = _pos.dy;

    SwipeDirection? dir;
    final verticalDominant = -dy > dx.abs();
    if (widget.superLikeEnabled &&
        verticalDominant &&
        (-dy > _commitUp || (v.dy < -1000 && -dy > 40))) {
      dir = SwipeDirection.up;
    } else if (dx > _commitX || (v.dx > 900 && dx > 24)) {
      dir = SwipeDirection.right;
    } else if (dx < -_commitX || (v.dx < -900 && dx < -24)) {
      dir = SwipeDirection.left;
    }

    if (dir != null && widget.items.isNotEmpty) {
      final item = widget.items.first;
      final allowed = widget.canSwipe?.call(item, dir) ?? true;
      if (!allowed) {
        widget.onBlocked?.call(item, dir);
        _startReturn(v);
        return;
      }
      _startFly(dir, fling: v);
    } else {
      _startReturn(v);
    }
  }

  void _onPanCancel() {
    if (_mode == _Mode.dragging) _startReturn(Offset.zero);
  }

  void _startReturn(Offset fling) {
    _mode = _Mode.returning;
    // سرعت رها کردن انگشت رو به فنر می‌دیم تا کارت «شناور» برگرده.
    final speed = fling.distance;
    _vel = speed > 3000 ? fling * (3000 / speed) : fling;
    _angleVel = 0;
    _startTicker();
  }

  /// پرت کردن با دکمه.
  void _flyOut(SwipeDirection dir) {
    if (widget.items.isEmpty || _mode == _Mode.flying || _mode == _Mode.dragging) {
      return;
    }
    final item = widget.items.first;
    final allowed = widget.canSwipe?.call(item, dir) ?? true;
    if (!allowed) {
      widget.onBlocked?.call(item, dir);
      return;
    }
    _startFly(dir, fling: Offset.zero);
  }

  void _startFly(SwipeDirection dir, {required Offset fling}) {
    HapticFeedback.mediumImpact();
    _flyDir = dir;
    _mode = _Mode.flying;
    final fromButton = fling == Offset.zero;
    final double vy = fromButton ? -200.0 : fling.dy.clamp(-900.0, 900.0).toDouble();
    switch (dir) {
      case SwipeDirection.right:
        _vel = Offset(math.max(fling.dx, 1700.0), vy);
        break;
      case SwipeDirection.left:
        _vel = Offset(math.min(fling.dx, -1700.0), vy);
        break;
      case SwipeDirection.up:
        _vel = Offset(fling.dx.clamp(-500.0, 500.0).toDouble(), math.min(fling.dy, -2200.0));
        break;
    }
    if (dir == SwipeDirection.up) {
      _flyAngleTarget = _angle;
    } else {
      final base = dir == SwipeDirection.right ? 1.0 : -1.0;
      final s = _angle.abs() > 0.03 ? _angle.sign : base;
      _flyAngleTarget = s * math.max(_angle.abs(), 0.32);
    }
    _startTicker();
  }

  // ---------------------------------------------------------------------
  // ساخت UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _size = Size(constraints.maxWidth, constraints.maxHeight);
      if (widget.items.isEmpty) return const SizedBox.shrink();

      _topCache ??= RepaintBoundary(child: widget.itemBuilder(context, widget.items.first));
      if (widget.items.length > 1) {
        _secondCache ??= RepaintBoundary(child: widget.itemBuilder(context, widget.items[1]));
      }

      final progress = _computeProgress();

      return Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          if (widget.items.length > 1)
            IgnorePointer(key: const ValueKey('swipe_second'), child: _secondCache!),
          GestureDetector(
            key: const ValueKey('swipe_top'),
            behavior: HitTestBehavior.opaque,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            onPanCancel: _onPanCancel,
            child: Transform.translate(
              offset: _pos,
              child: Transform.rotate(
                angle: _angle,
                child: Stack(
                  clipBehavior: Clip.none,
                  fit: StackFit.expand,
                  children: [
                    _topCache!,
                    _buildStamps(progress),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildStamps(SwipeProgress p) {
    final w = _size.width;
    final h = _size.height;
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (p.like > 0)
            Positioned(
              left: w * 0.14,
              top: 26,
              child: Opacity(
                opacity: (p.like * 1.5).clamp(0.0, 1.0).toDouble(),
                child: Transform.scale(
                  scale: 0.7 + 0.3 * p.like,
                  child: const Icon(Icons.favorite,
                      size: 84, color: SwipeColors.like),
                ),
              ),
            ),
          if (p.pass > 0)
            Positioned(
              right: w * 0.14,
              top: 34,
              child: Opacity(
                opacity: (p.pass * 1.5).clamp(0.0, 1.0).toDouble(),
                child: Transform.scale(
                  scale: 0.7 + 0.3 * p.pass,
                  child: const ThickXIcon(size: 64, stroke: 12, color: Colors.white),
                ),
              ),
            ),
          if (p.superLike > 0)
            Positioned(
              left: 0,
              right: 0,
              top: h * 0.28,
              child: Opacity(
                opacity: (p.superLike * 1.5).clamp(0.0, 1.0).toDouble(),
                child: Transform.scale(
                  scale: 0.7 + 0.3 * p.superLike,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 110, color: SwipeColors.superLike),
                      SizedBox(height: 4),
                      Text(
                        'سوپرلایک',
                        style: TextStyle(
                          color: SwipeColors.superLike,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ضربدر ضخیم با سرِ گرد — مثل ضربدر تیندر (آیکون Material خیلی نازکه).
class ThickXIcon extends StatelessWidget {
  final double size;
  final double stroke;
  final Color color;

  const ThickXIcon({
    super.key,
    required this.size,
    required this.stroke,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _XPainter(color: color, stroke: stroke),
    );
  }
}

class _XPainter extends CustomPainter {
  final Color color;
  final double stroke;
  _XPainter({required this.color, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final inset = stroke / 2;
    canvas.drawLine(Offset(inset, inset),
        Offset(size.width - inset, size.height - inset), paint);
    canvas.drawLine(Offset(size.width - inset, inset),
        Offset(inset, size.height - inset), paint);
  }

  @override
  bool shouldRepaint(covariant _XPainter old) =>
      old.color != color || old.stroke != stroke;
}
