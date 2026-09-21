import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'swipe_deck.dart';
import 'swipe_style.dart';

/// دکمه‌های پایین کارت.
///
/// - [extended] == false → حالت ۱ (بعد از اونبوردینگ): فقط ضربدر و قلب.
/// - [extended] == true  → حالت ۲: برگشت، ضربدر، ستاره، قلب، ارسال.
///
/// دکمه‌ها همزمان با کشیدن کارت پر می‌شن (از روی [progress]).
class SwipeActionBar extends StatelessWidget {
  final ValueListenable<SwipeProgress> progress;
  final bool extended;
  final bool canRewind;
  final VoidCallback onPass;
  final VoidCallback onLike;
  final VoidCallback onSuperLike;
  final VoidCallback onRewind;
  final VoidCallback onSend;

  const SwipeActionBar({
    super.key,
    required this.progress,
    required this.extended,
    required this.canRewind,
    required this.onPass,
    required this.onLike,
    required this.onSuperLike,
    required this.onRewind,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    // ترتیب فیزیکی ثابته (ضربدر چپ، قلب راست) چون جهت ژست‌ها هم فیزیکیه.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: extended ? _buildExtended() : _buildBasic(),
    );
  }

  Widget _buildBasic() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _passButton(size: SwipeMetrics.bigButton + 1, thick: false, dark: true),
        const SizedBox(width: 27),
        _likeButton(size: SwipeMetrics.bigButton + 1, filledRest: false, dark: true),
      ],
    );
  }

  Widget _buildExtended() {
    Widget slot(Widget child) => Expanded(child: Center(child: child));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7.5),
      child: Row(
        children: [
          slot(_rewindButton()),
          slot(_passButton(size: SwipeMetrics.bigButton, thick: true, dark: false)),
          slot(_superLikeButton()),
          slot(_likeButton(size: SwipeMetrics.bigButton, filledRest: true, dark: false)),
          slot(_sendButton()),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------

  Widget _passButton({required double size, required bool thick, required bool dark}) {
    return ValueListenableBuilder<SwipeProgress>(
      valueListenable: progress,
      builder: (context, p, _) {
        final t = (p.pass * 1.4).clamp(0.0, 1.0).toDouble();
        final rest = dark ? SwipeColors.black : SwipeColors.buttonBg;
        final bg = Color.lerp(rest, SwipeColors.pass, t)!;
        final fg = Color.lerp(Colors.white, const Color(0xFF101113), t)!;
        return _CircleButton(
          size: size,
          background: bg,
          border: dark ? null : SwipeColors.buttonBorder,
          scale: 1 + 0.08 * p.pass,
          onTap: onPass,
          child: ThickXIcon(size: 22, stroke: thick ? 5.5 : 2.8, color: fg),
        );
      },
    );
  }

  Widget _likeButton({required double size, required bool filledRest, required bool dark}) {
    return ValueListenableBuilder<SwipeProgress>(
      valueListenable: progress,
      builder: (context, p, _) {
        final t = (p.like * 1.4).clamp(0.0, 1.0).toDouble();
        final rest = dark ? SwipeColors.black : SwipeColors.buttonBg;
        final bg = Color.lerp(rest, SwipeColors.like, t)!;
        final fg = Color.lerp(SwipeColors.like, Colors.white, t)!;
        // تو حالت ۱ قلب اول توخالیه و وقتی نزدیک تأیید شد توپر می‌شه.
        final filled = filledRest || t > 0.7;
        return _CircleButton(
          size: size,
          background: bg,
          border: dark ? null : SwipeColors.buttonBorder,
          scale: 1 + 0.08 * p.like,
          onTap: onLike,
          child: Icon(filled ? Icons.favorite : Icons.favorite_border, size: 32, color: fg),
        );
      },
    );
  }

  Widget _superLikeButton() {
    return ValueListenableBuilder<SwipeProgress>(
      valueListenable: progress,
      builder: (context, p, _) {
        final t = p.superLike;
        final bg = Color.lerp(SwipeColors.buttonBg, SwipeColors.superLike, t)!;
        final fg = Color.lerp(SwipeColors.superLikeSoft, Colors.white, t)!;
        return _CircleButton(
          size: SwipeMetrics.smallButton,
          background: bg,
          border: SwipeColors.buttonBorder,
          scale: 1 + 0.1 * t,
          onTap: onSuperLike,
          child: Icon(Icons.star_rounded, size: 26, color: fg),
        );
      },
    );
  }

  Widget _rewindButton() {
    return _CircleButton(
      size: SwipeMetrics.smallButton,
      background: SwipeColors.buttonBg,
      border: SwipeColors.buttonBorder,
      onTap: canRewind ? onRewind : null,
      child: Icon(
        Icons.replay,
        size: 24,
        color: canRewind ? SwipeColors.rewind : SwipeColors.rewindDisabled,
      ),
    );
  }

  Widget _sendButton() {
    return _CircleButton(
      size: SwipeMetrics.smallButton,
      background: SwipeColors.buttonBg,
      border: SwipeColors.buttonBorder,
      onTap: onSend,
      child: const Icon(Icons.near_me, size: 22, color: SwipeColors.superLikeSoft),
    );
  }
}

class _CircleButton extends StatefulWidget {
  final double size;
  final Color background;
  final Color? border;
  final double scale;
  final VoidCallback? onTap;
  final Widget child;

  const _CircleButton({
    required this.size,
    required this.background,
    required this.child,
    this.border,
    this.scale = 1,
    this.onTap,
  });

  @override
  State<_CircleButton> createState() => _CircleButtonState();
}

class _CircleButtonState extends State<_CircleButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (widget.onTap == null) return;
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: widget.scale,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1,
        duration: const Duration(milliseconds: 90),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: widget.onTap == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  widget.onTap!();
                },
          child: Container(
            width: widget.size,
            height: widget.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.background,
              shape: BoxShape.circle,
              border: widget.border == null
                  ? null
                  : Border.all(color: widget.border!, width: 1),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
