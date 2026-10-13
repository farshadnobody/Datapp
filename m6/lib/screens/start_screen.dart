import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_ui.dart';
import 'login_screen.dart';
import 'code_request_screen.dart';

// ───────────────────────── تنظیمات ظاهر انیمیشن ─────────────────────────
// رنگ خود لوگو (از روی PNG نمونه‌گیری شده). موج قرمز هم همین رنگه، برای همین
// لحظه‌ای که موج به لوگو می‌رسه لوگو توش «حل می‌شه» و بعد سفید می‌شه.
const Color _kLogoRed = Color(0xFFF4473E);
// گرادیانت نهایی (سبک تیندر): بالا صورتی، پایین نارنجی-قرمز.
const Color _kGradTop = Color(0xFFFD267A);
const Color _kGradBottom = Color(0xFFFF6036);

const String _kLogoAsset = 'assets/logo/logo_nostar.png';
const String _kStarAsset = 'assets/logo/logo_star.png';

// ابعاد PNG لوگو (۱۵۵۰×۲۰۰۰) و جای دقیق ستاره داخلش (پیکسل ۴۶۹,۱۲۲ با
// اندازه‌ی ۲۸۵×۴۰۷) — از مقایسه‌ی پیکسلی لوگوی کامل و لوگوی بدون ستاره
// به‌دست اومده. اگه فایل‌ها رو عوض کردی این عددها رو هم عوض کن.
const double _kLogoAspect = 1550 / 2000;
const double _kStarLeft = 469 / 1550;
const double _kStarTop = 122 / 2000;
const double _kStarW = 285 / 1550;
const double _kStarH = 407 / 2000;

// مدت کل انیمیشن و زمان‌بندی هر مرحله (کسری از کل مدت).
const Duration _kIntroDuration = Duration(milliseconds: 3000);
const Interval _kWave = Interval(0.00, 0.30, curve: Curves.easeInOutCubic);
const Interval _kGradFade = Interval(0.28, 0.45, curve: Curves.easeOut);
const Interval _kMove = Interval(0.42, 0.70, curve: Curves.easeInOutCubic);
const Interval _kTwinkle = Interval(0.68, 0.90, curve: Curves.easeInOut);
// کاربر لاگین‌شده بعد از مرحله‌ی قرمز شدن مستقیم می‌ره صفحه‌ی بعد.
const double _kHandoffAt = 0.45;

// صفحه‌ی اول: انیمیشن لوگو (موج قرمز از لبه‌ها به لوگو می‌رسه، لوگو سفید
// می‌شه، پس‌زمینه گرادیانت تیندری می‌شه، لوگو می‌ره بالا و دکمه‌ها میان).
//
// [afterIntro]: اگه بدی (کاربر لاگین‌شده)، انیمیشن تا مرحله‌ی قرمز شدن اجرا
// می‌شه و بعد با fade می‌ره به همون صفحه؛ دکمه‌های لاگین نشون داده نمی‌شن.
class StartScreen extends StatefulWidget {
  final Widget? afterIntro;
  const StartScreen({super.key, this.afterIntro});

  // انیمیشن فقط یک بار به ازای هر بار باز شدن اپ اجرا می‌شه. بعد از خروج از
  // حساب یا منقضی شدن توکن، صفحه مستقیم با حالت نهایی باز می‌شه.
  static bool _introPlayed = false;

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _drift; // حرکت آروم گرادیانت بعد از انیمیشن
  late final AnimationController _fade; // فقط برای حالت «کاهش حرکت»

  // دکودِ نسخه‌ی کوچک‌شده‌ی PNGها تا حافظه‌ی زیادی نگیره.
  static const ImageProvider _logoImage =
      ResizeImage(AssetImage(_kLogoAsset), height: 1100);
  static const ImageProvider _starImage =
      ResizeImage(AssetImage(_kStarAsset), height: 320);

  bool _started = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: _kIntroDuration);
    _drift = AnimationController(
        vsync: this, duration: const Duration(seconds: 7));
    _fade = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400), value: 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _prepare(MediaQuery.of(context).disableAnimations);
  }

  Future<void> _prepare(bool reduceMotion) async {
    // قبل از شروع، تصویرها رو تو حافظه می‌گیریم تا وسط انیمیشن پرش نداشته باشیم.
    try {
      await Future.wait([
        precacheImage(_logoImage, context),
        precacheImage(_starImage, context),
      ]);
    } catch (_) {
      // اگه تصویری لود نشد، بازم انیمیشن (بدون اون تصویر) اجرا می‌شه.
    }
    if (!mounted) return;
    setState(() => _ready = true);

    final alreadyPlayed = StartScreen._introPlayed;
    StartScreen._introPlayed = true;

    if (alreadyPlayed || reduceMotion) {
      // حالت نهایی بدون انیمیشن (فقط یه fade ساده برای کاهش حرکت).
      _intro.value = 1.0;
      if (reduceMotion && !alreadyPlayed) {
        _fade.value = 0;
        await _fade.forward();
      }
      if (widget.afterIntro != null) {
        _goNext();
      } else {
        _drift.repeat(reverse: true);
      }
      return;
    }

    if (widget.afterIntro != null) {
      await _intro.animateTo(_kHandoffAt,
          duration: _kIntroDuration * _kHandoffAt, curve: Curves.linear);
      _goNext();
    } else {
      await _intro.forward();
      if (mounted) _drift.repeat(reverse: true);
    }
  }

  void _goNext() {
    final next = widget.afterIntro;
    if (!mounted || next == null) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => next,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    _drift.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnimatedBuilder(
        animation: Listenable.merge([_intro, _drift, _fade]),
        builder: (context, _) {
          final t = _intro.value;
          // اول پس‌زمینه سفیده (آیکن‌های استاتوس‌بار تیره)، بعد قرمز (روشن).
          final style = t > 0.15
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: style.copyWith(statusBarColor: Colors.transparent),
            child: Scaffold(
              backgroundColor: Colors.white,
              body: _ready
                  ? Opacity(opacity: _fade.value, child: _stage(context, t))
                  : const SizedBox.expand(),
            ),
          );
        },
      ),
    );
  }

  Widget _stage(BuildContext context, double t) {
    final media = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        final safeTop = media.padding.top;
        final safeBottom = media.padding.bottom;

        // اندازه و جای لوگو: وسط صفحه (شروع) → بالا و کوچک‌تر (پایان).
        final h0 = math.min(h * 0.34, 340.0);
        final h1 = math.min(h * 0.20, 190.0);
        final bottomBlock = 215.0 + safeBottom; // ارتفاع متن + دکمه‌ها
        final cy1 = safeTop + (h - bottomBlock - safeTop) / 2;
        final m = _kMove.transform(t);
        final logoH = ui.lerpDouble(h0, h1, m)!;
        final logoW = logoH * _kLogoAspect;
        final cy = ui.lerpDouble(h / 2, cy1, m)!;

        // موج قرمز: یه «سوراخ» دایره‌ای سفید که از لبه‌ها به مرکز جمع می‌شه.
        final r0 = math.sqrt(w * w + h * h) / 2 + 80;
        final radius = ui.lerpDouble(r0, 0, _kWave.transform(t))!;
        // لوگو همین‌که موج بهش نزدیک شد از قرمز به سفید می‌ره.
        final rLogo = h0 * 0.52 * 1.1;
        final whiteT = ((rLogo - radius) / rLogo).clamp(0.0, 1.0);
        final pulse = 1 + 0.05 * math.sin(math.pi * whiteT);
        final logoColor = Color.lerp(_kLogoRed, Colors.white, whiteT)!;

        // چشمک ستاره: یک بار بزرگ می‌شه، می‌چرخه (۹۰ درجه) و برمی‌گرده.
        final tw = _kTwinkle.transform(t);
        final starScale = 1 + 0.55 * math.sin(math.pi * tw);
        final starAngle = tw * math.pi / 2;

        final d = _drift.value;
        final gradOpacity = _kGradFade.transform(t);

        return Stack(
          fit: StackFit.expand,
          children: [
            // ۱) موج قرمز
            CustomPaint(
              painter: _WavePainter(
                radius: radius,
                center: Offset(w / 2, h / 2),
                feather: 90,
                color: _kLogoRed,
              ),
            ),
            // ۲) گرادیانت نهایی (با حرکت خیلی آروم بعد از اتمام انیمیشن)
            if (gradOpacity > 0)
              Opacity(
                opacity: gradOpacity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-1.0 + 0.6 * d, -1.0),
                      end: Alignment(1.0 - 0.6 * d, 1.0),
                      colors: const [_kGradTop, _kGradBottom],
                    ),
                  ),
                ),
              ),
            // ۳) لوگو + ستاره
            Positioned(
              left: w / 2 - logoW / 2,
              top: cy - logoH / 2,
              width: logoW,
              height: logoH,
              child: Transform.scale(
                scale: pulse,
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(logoColor, BlendMode.srcIn),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: Image(
                          image: _logoImage,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                      Positioned(
                        left: _kStarLeft * logoW,
                        top: _kStarTop * logoH,
                        width: _kStarW * logoW,
                        height: _kStarH * logoH,
                        child: Transform.rotate(
                          angle: starAngle,
                          child: Transform.scale(
                            scale: starScale,
                            child: Image(
                              image: _starImage,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // ۴) متن و دکمه‌ها (فقط برای کاربر لاگین‌نکرده)
            if (widget.afterIntro == null)
              Positioned(
                left: 24,
                right: 24,
                bottom: 24 + safeBottom,
                child: IgnorePointer(
                  ignoring: t < 0.85,
                  child: _bottomBlock(context, t),
                ),
              ),
          ],
        );
      },
    );
  }

  // ظاهر یکی از آیتم‌های پایین صفحه با fade + slide-up (پله‌پله).
  Widget _reveal(double t, double from, double to, Widget child) {
    final p = Interval(from, to, curve: Curves.easeOutCubic).transform(t);
    return Opacity(
      opacity: p,
      child: Transform.translate(offset: Offset(0, 28 * (1 - p)), child: child),
    );
  }

  // دکمه‌ها و متن‌ها دقیقاً همون صفحه‌ی قبلی هستن؛ فقط ورودشون انیمیت شده.
  Widget _bottomBlock(BuildContext context, double t) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // TODO: اگه صفحه‌ی قوانین/حریم خصوصی داری، به این متن لینک بده.
        _reveal(
          t,
          0.72,
          0.92,
          const Text(
            'با زدن «ادامه» قوانین و سیاست حریم خصوصی رو می‌پذیری.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _reveal(
          t,
          0.60,
          0.80,
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AuthColors.text,
                elevation: 0,
                shape: const StadiumBorder(),
                textStyle:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.phone, size: 20),
                  SizedBox(width: 12),
                  Text('ادامه با شماره موبایل'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _reveal(
          t,
          0.66,
          0.86,
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CodeRequestScreen()),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            child: const Text('ثبت‌نام یا فراموشی رمز؟'),
          ),
        ),
      ],
    );
  }
}

// موج قرمز: کل صفحه قرمزه، به‌جز یه سوراخ دایره‌ای با لبه‌ی نرم که شعاعش از
// گوشه‌ها به صفر می‌رسه. (saveLayer + dstOut تا لبه‌ی سوراخ واقعاً نرم باشه.)
class _WavePainter extends CustomPainter {
  final double radius;
  final Offset center;
  final double feather;
  final Color color;

  const _WavePainter({
    required this.radius,
    required this.center,
    required this.feather,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.saveLayer(rect, Paint());
    canvas.drawRect(rect, Paint()..color = color);
    if (radius > 0) {
      final f = math.min(feather, radius);
      final inner = ((radius - f) / radius).clamp(0.0, 1.0);
      final hole = Paint()
        ..blendMode = BlendMode.dstOut
        ..shader = ui.Gradient.radial(
          center,
          radius,
          const [Colors.black, Colors.black, Colors.transparent],
          [0.0, inner, 1.0],
        );
      canvas.drawRect(rect, hole);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.radius != radius ||
      old.center != center ||
      old.feather != feather ||
      old.color != color;
}
