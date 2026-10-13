import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../subscription/premium_paywall.dart';
import '../widgets/app_network_image.dart';
import 'promo_models.dart';
import 'promo_service.dart';

/// لایه‌ی تبلیغ‌ها: روی محتوای صفحه شناوره (پاپ‌آپ‌ها وسطِ صفحه، باکس‌ها پایین،
/// بالای نوار ناوبری). فقط خودِ باکس/پاپ‌آپ لمس می‌گیره؛ بقیه‌ی صفحه (اسکرول و...)
/// عادی کار می‌کنه.
class PromoHost extends StatefulWidget {
  /// کلیدِ صفحه‌ی فعلی: swipe | explore | likes | chat | profile
  final String screen;

  /// دکمه‌ای که مقصدش «رفتن به یه صفحه‌ی اپ» باشه، این رو صدا می‌زنه.
  final void Function(String screen) onNavigate;

  const PromoHost({super.key, required this.screen, required this.onNavigate});

  @override
  State<PromoHost> createState() => _PromoHostState();
}

class _PromoHostState extends State<PromoHost> {
  Promo? _popup;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    PromoService.instance.addListener(_onChanged);
    _scheduleNextPopup();
  }

  @override
  void didUpdateWidget(covariant PromoHost old) {
    super.didUpdateWidget(old);
    if (old.screen != widget.screen) {
      // با عوض شدنِ تب (مثلاً بعد از دکمه‌ی «برو به...»)، پاپ‌آپِ قبلی بسته می‌شه.
      _popup = null;
      _scheduleNextPopup();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    PromoService.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    _scheduleNextPopup();
  }

  /// کمی بعد از ورود به صفحه (تا ناگهانی نپره) پاپ‌آپِ بعدی رو نشون می‌ده.
  void _scheduleNextPopup() {
    if (_popup != null) return;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted || _popup != null) return;
      final next = PromoService.instance.nextPopup(widget.screen);
      if (next == null) return;
      PromoService.instance.markPopupShown(next);
      setState(() => _popup = next);
    });
  }

  void _closePopup() {
    if (!mounted) return;
    setState(() => _popup = null);
    _scheduleNextPopup(); // اگه پاپ‌آپِ دیگه‌ای تو صفه، بعدی میاد
  }

  Future<void> _runAction(Promo p) async {
    final url = p.actionUrl;
    if (url != null) {
      final uri = Uri.tryParse(url);
      if (uri != null && uri.scheme == 'https') {
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      }
    }
    final screen = p.actionScreen;
    if (!mounted) return;
    if (screen == 'premium') {
      openUpgrade(context);
    } else if (screen != null) {
      widget.onNavigate(screen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final banners = PromoService.instance.bannersFor(widget.screen);
    final popup = _popup;
    return Stack(
      children: [
        if (banners.isNotEmpty)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // اولین مورد پایین‌تر از همه می‌شینه، بقیه روش.
                    for (final b in banners.reversed)
                      Padding(
                        key: ValueKey<int>(b.id),
                        padding: const EdgeInsets.only(top: 6),
                        child: _FloatingDrag(
                          closable: b.closable,
                          onDismiss: () => PromoService.instance.dismissBanner(b),
                          child: _BannerCard(
                            promo: b,
                            onTap: b.hasAction ? () => _runAction(b) : null,
                            onClose: b.closable ? () => PromoService.instance.dismissBanner(b) : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        if (popup != null)
          _PopupLayer(
            key: ValueKey<int>(popup.id),
            promo: popup,
            onClose: _closePopup,
            onAction: () async {
              await _runAction(popup);
              _closePopup();
            },
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// پاپ‌آپ
// ---------------------------------------------------------------------------

class _PopupLayer extends StatefulWidget {
  final Promo promo;
  final VoidCallback onClose;
  final VoidCallback onAction;
  const _PopupLayer({super.key, required this.promo, required this.onClose, required this.onAction});

  @override
  State<_PopupLayer> createState() => _PopupLayerState();
}

class _PopupLayerState extends State<_PopupLayer> {
  final ValueNotifier<double> _fade = ValueNotifier<double>(0); // ۰ = کامل دیده می‌شه، ۱ = محو

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.promo;
    final width = math.min(340.0, MediaQuery.of(context).size.width - 48);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      builder: (context, appear, child) => Opacity(opacity: appear, child: child),
      child: Stack(
        children: [
          // پس‌زمینه‌ی تیره؛ فقط اگه پاپ‌آپ قابل‌بسته باشه، لمسش می‌بنده.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: p.closable ? widget.onClose : null,
              child: ValueListenableBuilder<double>(
                valueListenable: _fade,
                builder: (context, f, _) =>
                    ColoredBox(color: Colors.black.withOpacity(0.62 * (1 - f))),
              ),
            ),
          ),
          Center(
            child: _FloatingDrag(
              closable: p.closable,
              fade: _fade,
              onDismiss: widget.onClose,
              child: SizedBox(
                width: width,
                child: _PopupCard(promo: p, onClose: p.closable ? widget.onClose : null, onAction: widget.onAction),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PopupCard extends StatelessWidget {
  final Promo promo;
  final VoidCallback? onClose;
  final VoidCallback onAction;
  const _PopupCard({required this.promo, required this.onClose, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final p = promo;
    return Material(
      color: const Color(0xFF1C1C1E),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      elevation: 12,
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (p.imageUrl.isNotEmpty)
                SizedBox(
                  height: 160,
                  child: AppNetworkImage(
                    p.imageUrl,
                    fit: BoxFit.cover,
                    placeholderColor: const Color(0xFF2C2C2E),
                    errorBuilder: (_) => const ColoredBox(color: Color(0xFF2C2C2E)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (p.title.isNotEmpty)
                      Text(
                        p.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, height: 1.4),
                      ),
                    if (p.body.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        p.body,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFB5B5BC), fontSize: 14.5, height: 1.6),
                      ),
                    ],
                    if (p.buttonText.isNotEmpty && p.hasAction) ...[
                      const SizedBox(height: 18),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFC629),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: onAction,
                        child: Text(p.buttonText,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (onClose != null)
            PositionedDirectional(
              top: 8,
              start: 8,
              child: InkResponse(
                onTap: onClose,
                radius: 22,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(color: Color(0x99000000), shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// باکسِ شناورِ پایین
// ---------------------------------------------------------------------------

class _BannerCard extends StatelessWidget {
  final Promo promo;
  final VoidCallback? onTap;
  final VoidCallback? onClose;
  const _BannerCard({required this.promo, required this.onTap, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = promo;
    return Material(
      color: const Color(0xF2232327),
      borderRadius: BorderRadius.circular(16),
      elevation: 8,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52, maxHeight: 76),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 4, 6),
            child: Row(
              children: [
                if (p.imageUrl.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: AppNetworkImage(
                        p.imageUrl,
                        fit: BoxFit.cover,
                        placeholderColor: const Color(0xFF2C2C2E),
                        errorBuilder: (_) => const ColoredBox(color: Color(0xFF2C2C2E)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (p.title.isNotEmpty)
                        Text(p.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
                      if (p.body.isNotEmpty)
                        Text(p.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFFB5B5BC), fontSize: 12, height: 1.35)),
                    ],
                  ),
                ),
                if (p.buttonText.isNotEmpty && p.hasAction)
                  Container(
                    margin: const EdgeInsetsDirectional.only(start: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC629),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(p.buttonText,
                        style: const TextStyle(
                            color: Colors.black, fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                if (onClose != null)
                  InkResponse(
                    onTap: onClose,
                    radius: 20,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.close_rounded, color: Color(0xFF9A9AA3), size: 18),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// کشیدن به همه‌ی جهت‌ها
// ---------------------------------------------------------------------------

/// با انگشت به هر سمتی کشیده می‌شه (شناور دنبالِ انگشت حرکت می‌کنه).
///  - قابل‌بسته: اگه به‌اندازه‌ی کافی دور شد یا سریع پرتاب شد، همون‌طور که کشیده شده
///    از صفحه بیرون می‌ره و بسته می‌شه؛ وگرنه با فنر برمی‌گرده.
///  - غیرقابل‌بسته: فقط کمی (با مقاومت) کشیده می‌شه و همیشه برمی‌گرده.
class _FloatingDrag extends StatefulWidget {
  final Widget child;
  final bool closable;
  final VoidCallback onDismiss;

  /// (اختیاری) میزانِ محو شدنِ پس‌زمینه‌ی پاپ‌آپ: ۰ تا ۱.
  final ValueNotifier<double>? fade;

  const _FloatingDrag({
    required this.child,
    required this.closable,
    required this.onDismiss,
    this.fade,
  });

  @override
  State<_FloatingDrag> createState() => _FloatingDragState();
}

class _FloatingDragState extends State<_FloatingDrag> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  Offset _offset = Offset.zero;
  Animation<Offset>? _anim;
  bool _dismissing = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Offset get _current => _anim?.value ?? _offset;

  void _onPanStart(DragStartDetails d) {
    if (_dismissing) return;
    _c.stop();
    _offset = _current;
    _anim = null;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_dismissing) return;
    setState(() {
      if (widget.closable) {
        _offset += d.delta;
      } else {
        // مقاومت: هر چی دورتر، سخت‌تر کشیده می‌شه، تا سقفِ ~۵۰ پیکسل.
        final next = _offset + d.delta * 0.4;
        final dist = next.distance;
        _offset = dist > 50 ? next / dist * 50 : next;
      }
    });
    widget.fade?.value = (_offset.distance / 320).clamp(0.0, 1.0) * 0.6;
  }

  void _onPanEnd(DragEndDetails d) {
    if (_dismissing) return;
    final v = d.velocity.pixelsPerSecond;
    final far = _offset.distance > 90 || v.distance > 900;
    if (widget.closable && far) {
      // جهتِ خروج: جهتِ پرتاب، یا جهتی که تا الان کشیده شده.
      final dir = v.distance > 300 ? v / v.distance : (_offset.distance > 0 ? _offset / _offset.distance : const Offset(0, 1));
      _animateTo(_offset + dir * 700, const Duration(milliseconds: 240), Curves.easeIn, dismiss: true);
    } else {
      _animateTo(Offset.zero, const Duration(milliseconds: 320), Curves.easeOutBack, dismiss: false);
    }
  }

  void _animateTo(Offset target, Duration duration, Curve curve, {required bool dismiss}) {
    _dismissing = dismiss;
    _anim = Tween<Offset>(begin: _offset, end: target).animate(CurvedAnimation(parent: _c, curve: curve));
    _c.duration = duration;
    if (dismiss) widget.fade?.value = 1;
    _c.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      if (dismiss) {
        widget.onDismiss();
      } else {
        setState(() {
          _offset = Offset.zero;
          _anim = null;
        });
        widget.fade?.value = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final o = _current;
          final opacity = _dismissing ? (1 - _c.value).clamp(0.0, 1.0) : 1.0;
          return Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: o,
              child: Transform.rotate(angle: o.dx / 1800, child: child),
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
