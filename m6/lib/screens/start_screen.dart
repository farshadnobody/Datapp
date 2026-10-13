import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_ui.dart';
import 'login_screen.dart';
import 'code_request_screen.dart';

// ───────────────────────── تنظیمات ظاهر انیمیشن ─────────────────────────
// رنگ خود لوگو (از روی PNG نمونه‌گیری شده).
const Color _kLogoRed = Color(0xFFF4473E);
// گرادیانت نهایی (سبک تیندر): بالا صورتی، پایین نارنجی-قرمز.
const Color _kGradTop = Color(0xFFFD267A);
const Color _kGradBottom = Color(0xFFFF6036);
// رنگ برق (درخشش) شامپاینی که موقع سفید شدن لوگو از روش رد می‌شه.
const Color _kGlint = Color(0xFFFFE9BD);

const String _kLogoAsset = 'assets/logo/logo_nostar.png';
const String _kStarAsset = 'assets/logo/logo_star.png';
// ماسکِ شکل شعله (PNG با آلفا، هم‌ابعاد لوگو: ۱۵۵۰×۲۰۰۰). فایل mask.png رو
// بذار تو assets/logo/ (اگه کل پوشه تو pubspec هست، چیزی لازم نیست).
const String _kMaskAsset = 'assets/logo/mask.png';

// بزرگ‌ترین دایره‌ی داخل ماسک (از روی پیکسل‌ها): مرکزش (۰.۵۶۶، ۰.۶۸۵) و
// شعاعش ۰.۳۹ عرضِ ماسکه. موقع شروع این نقطه رو وسط صفحه می‌ذاریم و اندازه‌ی
// ماسک رو اونقدر بزرگ می‌گیریم که کل صفحه توی این دایره بیفته (یعنی صفحه
// کاملاً سفید دیده بشه)؛ بعد ماسک کوچیک می‌شه تا هم‌اندازه‌ی لوگو بشه.
const double _kMaskAnchorX = 0.566;
const double _kMaskAnchorY = 0.685;
const double _kMaskSafeR = 0.39;

// ابعاد PNG لوگو (۱۵۵۰×۲۰۰۰) و جای دقیق ستاره داخلش (پیکسل ۴۶۹,۱۲۲ با
// اندازه‌ی ۲۸۵×۴۰۷) — از مقایسه‌ی پیکسلی لوگوی کامل و لوگوی بدون ستاره
// به‌دست اومده. اگه فایل‌ها رو عوض کردی این عددها رو هم عوض کن.
const double _kLogoAspect = 1550 / 2000;
const double _kStarLeft = 469 / 1550;
const double _kStarTop = 122 / 2000;
const double _kStarW = 285 / 1550;
const double _kStarH = 407 / 2000;

// مدت کل انیمیشن و زمان‌بندی هر مرحله (کسری از کل مدت).
// ۱) لوگوی قرمز (بدون ستاره) آروم ظاهر می‌شه
// ۲) صفحه سفیده و داخل یه ماسکِ شعله‌ایِ خیلی بزرگه؛ بیرونِ ماسک گرادیانت
//    رنگیه. ماسک کوچیک می‌شه تا هم‌اندازه‌ی لوگو بشه و صفحه رنگی بشه
// ۳) یه برقِ مورب از روی لوگو رد می‌شه و پشت سرش لوگو سفید می‌شه
// ۴) لوگو می‌ره بالا و دکمه‌ها میان
// ۵) ستاره با یه چشمک ظاهر می‌شه
const Duration _kIntroDuration = Duration(milliseconds: 5400);
const Interval _kLogoIn = Interval(0.00, 0.14, curve: Curves.easeOutCubic);
// لوگوی قرمز اول روی صفحه‌ی سفید خیلی کم‌رنگه (شفافیت [_kLogoGhost]) و وقتی
// ماسک بهش می‌رسه کامل ظاهر می‌شه. بازه‌ی ظاهر شدن روی پیشرفتِ کوچیک شدنِ
// ماسک (۰ تا ۱) تعریف شده، نه روی زمان کل.
const double _kLogoGhost = 0.0;
const Interval _kLogoReveal = Interval(1, 1, curve: Curves.easeOut);
// کوچیک شدنِ ماسک: از خیلی بزرگ (صفحه‌ی سفید) تا هم‌اندازه‌ی لوگو.
const Interval _kWave = Interval(0.10, 0.38, curve: Curves.easeInOutCubic);
// داخلِ سوراخِ ماسک آخرِ کوچیک شدن با گرادیانت پر می‌شه (پشت لوگو).
const Interval _kGradFill = Interval(0.34, 0.38, curve: Curves.easeIn);
const Interval _kWipe = Interval(0.24, 0.55, curve: Curves.easeInOutCubic);
const Interval _kMove = Interval(0.46, 0.72, curve: Curves.easeInOutCubic);
const Interval _kTwinkle = Interval(0.70, 0.94);
// کاربر لاگین‌شده بعد از سفید شدن لوگو مستقیم می‌ره صفحه‌ی بعد.
const double _kHandoffAt = 0.55;

// صفحه‌ی اول: انیمیشن لوگو (لوگوی قرمز ظاهر می‌شه، پس‌زمینه گرادیانت تیندری
// می‌شه، یه برق از روی لوگو رد می‌شه و لوگو سفید می‌شه، لوگو می‌ره بالا،
// دکمه‌ها میان و آخرش ستاره چشمک می‌زنه).
//
// [afterIntro]: اگه بدی (کاربر لاگین‌شده)، انیمیشن تا مرحله‌ی سفید شدن اجرا
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

  ui.Image? _mask; // ماسک شعله (برای سوراخ کردن لایه‌ی گرادیانت)
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
        _loadMask(),
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

  Future<void> _loadMask() async {
    final data = await rootBundle.load(_kMaskAsset);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetHeight: 1400,
    );
    final frame = await codec.getNextFrame();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    _mask = frame.image;
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
    _mask?.dispose();
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
          // اول پس‌زمینه سفیده (آیکن‌های استاتوس‌بار تیره)، بعد رنگی (روشن).
          final style = _kWave.transform(t) > 0.5
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

        // ورود لوگو: fade + یه بزرگ‌شدنِ خیلی کم.
        final inP = _kLogoIn.transform(t);
        final logoScale = ui.lerpDouble(0.94, 1.0, inP)!;

        // برقِ مورب: w از ۰ تا ۱ می‌ره؛ پشتِ برق لوگو سفیده، جلوش هنوز قرمز.
        final wipe = _kWipe.transform(t);

        // چشمک ستاره (ثابت سر جای خودش، بدون چرخش):
        // ۱) از هیچی با یه فنر کوچیک ظاهر می‌شه ۲) یه بار نرم نفس می‌کشه.
        final tw = _kTwinkle.transform(t);
        final appear = (tw / 0.55).clamp(0.0, 1.0);
        final breathe = ((tw - 0.55) / 0.45).clamp(0.0, 1.0);
        final starScale = Curves.easeOutBack.transform(appear) *
            (1 + 0.12 * math.sin(math.pi * breathe));
        final starOpacity = (tw / 0.2).clamp(0.0, 1.0);
        final flare = math.sin(math.pi * (tw / 0.75).clamp(0.0, 1.0));

        final d = _drift.value;
        final gradOpacity = _kGradFill.transform(t);
        final waveP = _kWave.transform(t);
        final logoOpacity =
            ui.lerpDouble(_kLogoGhost, 1.0, _kLogoReveal.transform(waveP))!;

        // مرکز ستاره نسبت به جعبه‌ی لوگو + اندازه‌ی جعبه‌ی درخشش.
        final starCx = (_kStarLeft + _kStarW / 2) * logoW;
        final starCy = (_kStarTop + _kStarH / 2) * logoH;
        final flareSize = _kStarH * logoH * 2.6;

        return Stack(
          fit: StackFit.expand,
          children: [
            // ۱) گرادیانت نهایی (با حرکت خیلی آروم بعد از انیمیشن)
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
            // ۱.۵) گرادیانتِ بیرونِ ماسک: ماسک (شکل شعله) از خیلی بزرگ تا
            // هم‌اندازه‌ی لوگو کوچیک می‌شه؛ داخلش سفیده (اول) و بعد با
            // گرادیانتِ لایه‌ی زیرش پر می‌شه.
            if (waveP > 0 && waveP < 1 && _mask != null)
              _maskLayer(
                p: waveP,
                w: w,
                h: h,
                cy: cy,
                logoW: logoW,
                logoH: logoH,
                drift: d,
              ),
            // ۲) لوگو + ستاره
            Positioned(
              left: w / 2 - logoW / 2,
              top: cy - logoH / 2,
              width: logoW,
              height: logoH,
              child: Opacity(
                opacity: logoOpacity,
                child: Transform.scale(
                  scale: logoScale,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(child: _logoLayer(wipe)),
                      // درخشش و پرتوی چشمک (پشت ستاره)
                      if (flare > 0)
                        Positioned(
                          left: starCx - flareSize / 2,
                          top: starCy - flareSize / 2,
                          width: flareSize,
                          height: flareSize,
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _SparklePainter(amp: flare),
                            ),
                          ),
                        ),
                      // خود ستاره (سفید؛ چون بعد از سفید شدن لوگو میاد)
                      if (starScale > 0)
                        Positioned(
                          left: _kStarLeft * logoW,
                          top: _kStarTop * logoH,
                          width: _kStarW * logoW,
                          height: _kStarH * logoH,
                          child: Opacity(
                            opacity: starOpacity,
                            child: Transform.scale(
                              scale: starScale,
                              child: ColorFiltered(
                                colorFilter: const ColorFilter.mode(
                                    Colors.white, BlendMode.srcIn),
                                child: Image(
                                  image: _starImage,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                ),
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
                  ignoring: t < 0.9,
                  child: _bottomBlock(context, t),
                ),
              ),
          ],
        );
      },
    );
  }

  // لایه‌ی ماسک: کل صفحه گرادیانتِ نهاییه، به‌جز یه سوراخ به شکل شعله که
  // [p] از ۰ تا ۱ کوچیک می‌شه. در p=۰ سوراخ کل صفحه رو می‌پوشونه (صفحه سفید)
  // و در p=۱ دقیقاً هم‌اندازه و هم‌جای لوگو (logoW×logoH) می‌شه.
  Widget _maskLayer({
    required double p,
    required double w,
    required double h,
    required double cy,
    required double logoW,
    required double logoH,
    required double drift,
  }) {
    final halfDiag = math.sqrt(w * w + h * h) / 2;
    // ضریب بزرگ‌نمایی اولیه نسبت به اندازه‌ی لوگو (کمی حاشیه‌ی اطمینان).
    final k0 = halfDiag * 1.08 / (_kMaskSafeR * logoW);
    final s = math.pow(k0, 1 - p).toDouble();
    // نقطه‌ی لنگر: اول جای امن داخل شعله، آخر مرکز لوگو.
    final ax = ui.lerpDouble(_kMaskAnchorX, 0.5, p)!;
    final ay = ui.lerpDouble(_kMaskAnchorY, 0.5, p)!;
    final mw = logoW * s;
    final mh = logoH * s;
    final rect = Rect.fromLTWH(w / 2 - ax * mw, cy - ay * mh, mw, mh);
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _MaskHolePainter(
            mask: _mask!,
            rect: rect,
            gBegin: Offset(0.3 * drift * w, 0),
            gEnd: Offset((1 - 0.3 * drift) * w, h),
          ),
        ),
      ),
    );
  }

  // لوگوی قرمز + برقِ مورب. [wipe] از ۰ تا ۱: پشتِ برق سفید، جلوش قرمز.
  // لبه‌ی برق یه درخششِ شامپاینی داره تا حس «فلز براق» بده.
  Widget _logoLayer(double wipe) {
    const red = ColorFilter.mode(_kLogoRed, BlendMode.srcIn);
    const white = ColorFilter.mode(Colors.white, BlendMode.srcIn);
    final img = Image(
      image: _logoImage,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
    if (wipe <= 0) {
      return ColorFiltered(colorFilter: red, child: img);
    }
    if (wipe >= 1) {
      return ColorFiltered(colorFilter: white, child: img);
    }
    final p = ui.lerpDouble(-0.2, 1.2, wipe)!;
    double s(double v) => v.clamp(0.0, 1.0);
    final glintClear = Color(0x00FFE9BD);
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white,
          Colors.white,
          _kGlint,
          glintClear,
          glintClear,
        ],
        stops: [0.0, s(p - 0.20), s(p - 0.04), s(p + 0.12), 1.0],
      ).createShader(rect),
      child: ColorFiltered(colorFilter: red, child: img),
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
          0.78,
          0.96,
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
          0.66,
          0.86,
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
          0.72,
          0.92,
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

// گرادیانتِ تمام‌صفحه با یه سوراخ به شکل ماسک (dstOut = هرجا ماسک پُره،
// گرادیانت پاک می‌شه). گرادیانت با مختصات صفحه محاسبه می‌شه تا دقیقاً با
// لایه‌ی گرادیانتِ زیرش یکی باشه.
class _MaskHolePainter extends CustomPainter {
  final ui.Image mask;
  final Rect rect;
  final Offset gBegin;
  final Offset gEnd;
  const _MaskHolePainter({
    required this.mask,
    required this.rect,
    required this.gBegin,
    required this.gEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    canvas.saveLayer(full, Paint());
    canvas.drawRect(
      full,
      Paint()
        ..shader = ui.Gradient.linear(
          gBegin,
          gEnd,
          const [_kGradTop, _kGradBottom],
        ),
    );
    canvas.drawImageRect(
      mask,
      Rect.fromLTWH(0, 0, mask.width.toDouble(), mask.height.toDouble()),
      rect,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..filterQuality = FilterQuality.high
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MaskHolePainter old) =>
      old.rect != rect ||
      old.gBegin != gBegin ||
      old.gEnd != gEnd ||
      old.mask != mask;
}

// درخشش و پرتوی چشمک ستاره: یه هاله‌ی نرم + دو خط نازک (افقی و عمودی) که
// از وسط به دو طرف محو می‌شن. [amp] از ۰ تا ۱ و دوباره ۰.
class _SparklePainter extends CustomPainter {
  final double amp;
  const _SparklePainter({required this.amp});

  @override
  void paint(Canvas canvas, Size size) {
    if (amp <= 0) return;
    final c = size.center(Offset.zero);
    final half = size.shortestSide / 2;

    // هاله
    final glowR = half * 0.55;
    canvas.drawCircle(
      c,
      glowR,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          glowR,
          [
            Color.fromRGBO(255, 255, 255, 0.55 * amp),
            const Color.fromRGBO(255, 255, 255, 0),
          ],
        ),
    );

    // پرتوها
    final len = half * amp;
    final line = Paint()
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final fadeColors = [
      const Color.fromRGBO(255, 255, 255, 0),
      Color.fromRGBO(255, 255, 255, 0.95 * amp),
      const Color.fromRGBO(255, 255, 255, 0),
    ];
    final h0 = Offset(c.dx - len, c.dy);
    final h1 = Offset(c.dx + len, c.dy);
    canvas.drawLine(
      h0,
      h1,
      line..shader = ui.Gradient.linear(h0, h1, fadeColors, [0.0, 0.5, 1.0]),
    );
    final v0 = Offset(c.dx, c.dy - len);
    final v1 = Offset(c.dx, c.dy + len);
    canvas.drawLine(
      v0,
      v1,
      line..shader = ui.Gradient.linear(v0, v1, fadeColors, [0.0, 0.5, 1.0]),
    );
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.amp != amp;
}
