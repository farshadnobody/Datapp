import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'remove_like_hint.dart';
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

  /// true → این فرد قبلاً لایک/سوپرلایک شده؛ دکمه از قبل «روشن» نشون داده می‌شه.
  /// دوباره زدنش فقط کارت رو رد می‌کنه و چیزی تو دیتابیس عوض نمی‌شه.
  final bool likeLit;
  final bool superLikeLit;

  /// نگه داشتنِ طولانیِ دکمه‌ی روشنِ لایک/سوپرلایک → برداشتنِ لایک (با تأیید).
  final VoidCallback? onRemoveLike;

  /// true → ضربدر/ستاره/قلب/واگرد با محو و کوچیک شدن هاید می‌شن (دکمه‌ی ارسال
  /// سر جاش می‌مونه). وقتی اطلاعاتِ پروفایل باز شده استفاده می‌شه.
  final bool hideActions;

  /// true → دکمه‌ی ارسال هم هاید می‌شه. وقتی کارت بازه، ارسال روی خودِ کارت
  /// می‌شینه و با اسکرول حرکت می‌کنه، پس این‌جا نباید ثابت بمونه.
  final bool hideSend;
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
    this.likeLit = false,
    this.superLikeLit = false,
    this.onRemoveLike,
    this.hideActions = false,
    this.hideSend = false,
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
        _hideable(_passButton(size: SwipeMetrics.bigButton + 1, thick: false, dark: true)),
        const SizedBox(width: 27),
        _hideable(_likeButton(size: SwipeMetrics.bigButton + 1, filledRest: false, dark: true)),
      ],
    );
  }

  Widget _buildExtended() {
    Widget slot(Widget child) => Expanded(child: Center(child: child));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7.5),
      child: Row(
        children: [
          slot(_hideable(_rewindButton())),
          slot(_hideable(_passButton(size: SwipeMetrics.bigButton, thick: true, dark: false))),
          slot(_hideable(_superLikeButton())),
          slot(_hideable(_likeButton(size: SwipeMetrics.bigButton, filledRest: true, dark: false))),
          slot(_hideable(_sendButton(), hidden: hideSend)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------

  /// هاید/نمایان شدنِ سریع و ملایم. فقط به یه مقدارِ بولین وصله (نه به مقدارِ
  /// اسکرول)، پس همیشه خودش کامل می‌شه و نمی‌شه نیمه‌هاید نگهش داشت.
  static const Duration _hideDuration = Duration(milliseconds: 120);

  Widget _hideable(Widget child, {bool? hidden}) {
    final hide = hidden ?? hideActions;
    return IgnorePointer(
      ignoring: hide,
      child: AnimatedOpacity(
        opacity: hide ? 0 : 1,
        duration: _hideDuration,
        curve: Curves.easeOut,
        child: AnimatedScale(
          scale: hide ? 0.85 : 1,
          duration: _hideDuration,
          curve: Curves.easeOut,
          child: child,
        ),
      ),
    );
  }

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
        final t = likeLit ? 1.0 : (p.like * 1.4).clamp(0.0, 1.0).toDouble();
        final rest = dark ? SwipeColors.black : SwipeColors.buttonBg;
        final bg = Color.lerp(rest, SwipeColors.like, t)!;
        final fg = Color.lerp(SwipeColors.like, Colors.white, t)!;
        // تو حالت ۱ قلب اول توخالیه و وقتی نزدیک تأیید شد توپر می‌شه.
        final filled = filledRest || t > 0.7;
        return _HintAnchor(
          lit: likeLit && onRemoveLike != null,
          buttonSize: size,
          label: 'نگه دار تا لایک برداشته بشه',
          child: _CircleButton(
            size: size,
            background: bg,
            border: dark ? null : SwipeColors.buttonBorder,
            scale: 1 + 0.08 * p.like,
            onTap: onLike,
            onLongPress: likeLit ? onRemoveLike : null,
            child: Icon(filled ? Icons.favorite : Icons.favorite_border, size: 32, color: fg),
          ),
        );
      },
    );
  }

  Widget _superLikeButton() {
    return ValueListenableBuilder<SwipeProgress>(
      valueListenable: progress,
      builder: (context, p, _) {
        final t = superLikeLit ? 1.0 : p.superLike;
        final bg = Color.lerp(SwipeColors.buttonBg, SwipeColors.superLike, t)!;
        final fg = Color.lerp(SwipeColors.superLikeSoft, Colors.white, t)!;
        return _HintAnchor(
          lit: superLikeLit && onRemoveLike != null,
          buttonSize: SwipeMetrics.smallButton,
          label: 'نگه دار تا سوپرلایک برداشته بشه',
          child: _CircleButton(
            size: SwipeMetrics.smallButton,
            background: bg,
            border: SwipeColors.buttonBorder,
            scale: 1 + 0.1 * t,
            onTap: onSuperLike,
            onLongPress: superLikeLit ? onRemoveLike : null,
            child: Icon(Icons.star_rounded, size: 26, color: fg),
          ),
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

/// حباب راهنمای یک‌باره بالای دکمه‌ی روشن. اولین باری که یه دکمه‌ی لایک/سوپرلایکِ
/// روشن دیده می‌شه ~۴ ثانیه نشون داده می‌شه و دیگه هیچ‌وقت تکرار نمی‌شه
/// (وضعیتش با [RemoveLikeHint] روی گوشی ذخیره می‌شه).
class _HintAnchor extends StatefulWidget {
  final bool lit;
  final double buttonSize;
  final String label;
  final Widget child;
  const _HintAnchor({
    required this.lit,
    required this.buttonSize,
    required this.label,
    required this.child,
  });

  @override
  State<_HintAnchor> createState() => _HintAnchorState();
}

class _HintAnchorState extends State<_HintAnchor> {
  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _maybeStart();
  }

  @override
  void didUpdateWidget(covariant _HintAnchor old) {
    super.didUpdateWidget(old);
    if (widget.lit && !old.lit) _maybeStart();
  }

  void _maybeStart() {
    if (!widget.lit || _visible || !RemoveLikeHint.shouldShow) return;
    _visible = true;
    RemoveLikeHint.markSeen();
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final show = _visible && widget.lit;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        widget.child,
        Positioned(
          bottom: widget.buttonSize + 10,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: OverflowBox(
              minWidth: 0,
              maxWidth: 260,
              minHeight: 0,
              maxHeight: 60,
              alignment: Alignment.bottomCenter,
              child: AnimatedOpacity(
                opacity: show ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xEE2C2C2E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatefulWidget {
  final double size;
  final Color background;
  final Color? border;
  final double scale;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  const _CircleButton({
    required this.size,
    required this.background,
    required this.child,
    this.border,
    this.scale = 1,
    this.onTap,
    this.onLongPress,
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
          onLongPress: widget.onLongPress == null
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  widget.onLongPress!();
                },
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
