import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_ui.dart';
import 'login_screen.dart';
import 'code_request_screen.dart';

// ───────────────────────── تنظیمات ظاهر انیمیشن ─────────────────────────
// رنگ خود لوگو قبل از سفید شدن — صورتیِ برند (هم‌رنگ سرِ گرادیانت).
const Color _kLogoRed = Color(0xFFFD267A);
// گرادیانت نهایی (سبک تیندر): بالا صورتی، پایین نارنجی.
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
// ───────────────────────── زمان‌بندی انیمیشن (به میلی‌ثانیه) ─────────────────────────
// هر بخش رو جدا تنظیم کن؛ مدت کل و بازه‌های کسریِ پایین خودکار حساب می‌شن.
// ترتیب: تأخیر اولیه ← کوچیک شدنِ ماسک (+ محو شدن) ← مکث ← حرکت لوگو ←
//        چشمک ستاره ← ظاهر شدنِ متن و دکمه‌ها.

/// صفحه‌ی سفید قبل از شروعِ کوچیک شدنِ ماسک.
const int _msDelay = 1;

/// مدتِ کوچیک شدنِ ماسک و لوگو (از خیلی بزرگ تا اندازه‌ی عادی).
const int _msMask = 1836;

/// مدتِ دو برقِ مورب (محو شدنِ ماسک + ظاهر شدنِ لوگو). همیشه هم‌زمان با
/// پایانِ کوچیک شدنِ ماسک تموم می‌شه؛ پس شروعش = پایان ماسک − این مقدار.
/// نباید از _msDelay + _msMask بیشتر باشه.
const int _msFade = 1080;

/// مکثِ لوگوی سفید بعد از تموم شدنِ ماسک، قبل از رفتن به بالا.
const int _msHold = 540;

/// مدتِ حرکت (بالا رفتن و کوچیک شدن) لوگو.
const int _msMove = 864;

/// مدتِ چشمکِ ستاره.
const int _msTwinkle = 810;

/// ستاره این‌قدر قبل از تموم شدنِ حرکتِ لوگو شروع می‌شه (منفی = بعد از آن).
const int _msTwinkleLead = 54;

// ظاهر شدنِ متن و دکمه‌ها: (شروع نسبت به پایانِ حرکتِ لوگو، مدت). شروعِ منفی
// یعنی قبل از تموم شدنِ حرکت.
const int _msBtnMainAt = -162, _msBtnMainDur = 648; // دکمه‌ی «ادامه»
const int _msBtnSecAt = 0, _msBtnSecDur = 702; // دکمه‌ی دوم
const int _msTextAt = 216, _msTextDur = 648; // متن قوانین

/// مکثِ آخر بعد از تموم شدنِ آخرین بخش (فقط برای زمانِ کل).
const int _msTail = 0;

// ───────────────────────── مقادیر خودکار؛ دست نزن ─────────────────────────
const int _tMaskStart = _msDelay;
const int _tMaskEnd = _tMaskStart + _msMask;
const int _tMoveStart = _tMaskEnd + _msHold;
const int _tMoveEnd = _tMoveStart + _msMove;
const int _tTwinkleStart = _tMoveEnd - _msTwinkleLead;
const int _tTwinkleEnd = _tTwinkleStart + _msTwinkle;
const int _tBtnMainEnd = _tMoveEnd + _msBtnMainAt + _msBtnMainDur;
const int _tBtnSecEnd = _tMoveEnd + _msBtnSecAt + _msBtnSecDur;
const int _tTextEnd = _tMoveEnd + _msTextAt + _msTextDur;
const int _tLastA = _tTwinkleEnd > _tTextEnd ? _tTwinkleEnd : _tTextEnd;
const int _tLastB = _tBtnMainEnd > _tBtnSecEnd ? _tBtnMainEnd : _tBtnSecEnd;
const int _tTotal = (_tLastA > _tLastB ? _tLastA : _tLastB) + _msTail;

/// میلی‌ثانیه ← کسری از کلِ انیمیشن (۰ تا ۱).
double _f(int ms) => ms / _tTotal;

const Duration _kIntroDuration = Duration(milliseconds: _tTotal);
final Interval _kWave =
    Interval(_f(_tMaskStart), _f(_tMaskEnd), curve: Curves.easeInOutCubic);
final Interval _kGradFill =
    Interval(_f(_tMaskEnd - _msFade), _f(_tMaskEnd), curve: Curves.easeInOut);
// پهنای لبه‌ی نرمِ دو برقِ مورب، نسبت به قطرِ لوگو.
const double _kRevealSoft = 0.25;
final Interval _kMove = Interval(_f(_tMoveStart), _f(_tMoveEnd),
    curve: Curves.easeInOutCubic);
final Interval _kTwinkle = Interval(_f(_tTwinkleStart), _f(_tTwinkleEnd));
// کاربر لاگین‌شده بعد از سفید شدن لوگو مستقیم می‌ره صفحه‌ی بعد.
final double _kHandoffAt = _f(_tMoveStart);
// لمسِ دکمه‌ها وقتی فعال می‌شه که هر دو دکمه کامل ظاهر شدن.
final double _kInteractAt =
    _f(_tBtnMainEnd > _tBtnSecEnd ? _tBtnMainEnd : _tBtnSecEnd);

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


        // برقِ مورب: w از ۰ تا ۱ می‌ره؛ پشتِ برق لوگو سفیده، جلوش هنوز قرمز.

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
        final fillP = _kGradFill.transform(t); // ۰..۱: برقِ پر شدنِ ماسک + ظاهر شدنِ لوگو
        final waveP = _kWave.transform(t);

        // جعبه‌ی مشترکِ ماسک و لوگو: لوگو دقیقاً هم‌اندازه‌ی ماسکه و با اون
        // کوچیک می‌شه. بعد از تموم شدن ماسک همون جعبه‌ی عادیِ لوگوئه.
        final maskBox = waveP >= 1
            ? Rect.fromCenter(
                center: Offset(w / 2, cy), width: logoW, height: logoH)
            : _maskRect(
                p: waveP, w: w, h: h, cy: cy, logoW: logoW, logoH: logoH);

        // مرکز ستاره نسبت به جعبه‌ی لوگو + اندازه‌ی جعبه‌ی درخشش.
        final starCx = (_kStarLeft + _kStarW / 2) * logoW;
        final starCy = (_kStarTop + _kStarH / 2) * logoH;
        final flareSize = _kStarH * logoH * 2.6;

        return Stack(
          fit: StackFit.expand,
          children: [
            // ۱) گرادیانت نهایی (با حرکت خیلی آروم بعد از انیمیشن). داخلِ
            // سوراخِ ماسک با یه برقِ مورب از بالا-چپ تا پایین-راست پدیدار می‌شه.
            if (fillP > 0)
              _diagReveal(
                p: fillP,
                from: _Diag.topLeftToBottomRight,
                center: maskBox.center,
                boxW: maskBox.width,
                boxH: maskBox.height,
                behind: const Color(0xFFFFFFFF),
                ahead: const Color(0x00FFFFFF),
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
              _maskLayer(rect: maskBox, drift: d, w: w, h: h),
            // ۲) لوگو + ستاره
            Positioned(
              left: maskBox.left,
              top: maskBox.top,
              width: maskBox.width,
              height: maskBox.height,
              child: Transform.scale(
                  scale: 1.0, // اندازه‌ی لوگو از خودِ جعبه‌ی ماسک میاد
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        // ظاهر شدنِ لوگوی سفید: برقِ مورب از بالا-چپ تا
                        // پایین-راست؛ جلوی برق نامرئی، پشتش سفیدِ کامل.
                        child: _diagReveal(
                          p: fillP,
                          from: _Diag.topLeftToBottomRight,
                          behind: const Color(0xFFFFFFFF),
                          ahead: const Color(0x00FFFFFF),
                          child: _logoLayer(1.0), // لوگو از اول سفیده
                        ),
                      ),
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
            // ۴) متن و دکمه‌ها (فقط برای کاربر لاگین‌نکرده)
            if (widget.afterIntro == null)
              Positioned(
                left: 24,
                right: 24,
                bottom: 24 + safeBottom,
                child: IgnorePointer(
                  ignoring: t < _kInteractAt,
                  child: _bottomBlock(context, t),
                ),
              ),
          ],
        );
      },
    );
  }

  // جعبه‌ی ماسک (و لوگو) در پیشرفتِ [p] از ۰ تا ۱: اول خیلی بزرگ، و آخر
  // دقیقاً هم‌اندازه و هم‌جای لوگو (logoW×logoH، مرکز: وسط صفحه و cy).
  Rect _maskRect({
    required double p,
    required double w,
    required double h,
    required double cy,
    required double logoW,
    required double logoH,
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
    return Rect.fromLTWH(w / 2 - ax * mw, cy - ay * mh, mw, mh);
  }

  // لایه‌ی ماسک: کل صفحه گرادیانتِ نهاییه، به‌جز یه سوراخ به شکل شعله در
  // جعبه‌ی [rect] (همون جعبه‌ی لوگو؛ پس لوگو دقیقاً داخل سوراخ می‌شینه).
  Widget _maskLayer({
    required Rect rect,
    required double drift,
    required double w,
    required double h,
  }) {
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

  // برقِ مورب برای ظاهر/محو شدن: [p] از ۰ تا ۱. پشتِ برق رنگِ [behind]
  // (آلفای ماسک)، جلوش [ahead]. جهتِ برق با [from] مشخص می‌شه. اگه [center] و
  // [boxW]/[boxH] داده بشه، برق نسبت به اون جعبه محاسبه می‌شه (برای لایه‌ی
  // تمام‌صفحه)؛ وگرنه نسبت به خودِ child.
  Widget _diagReveal({
    required double p,
    required _Diag from,
    required Color behind,
    required Color ahead,
    required Widget child,
    Offset? center,
    double? boxW,
    double? boxH,
  }) {
    if (p >= 1) return child; // برق تموم شده: همه‌جا «پشتِ برق» است
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        final bw = boxW ?? rect.width;
        final bh = boxH ?? rect.height;
        final c = center ?? rect.center;
        final dir = from == _Diag.topLeftToBottomRight
            ? Offset(bw, bh)
            : Offset(-bw, bh);
        final len = dir.distance;
        final u = dir / len;
        final hb = len / 2; // نصفِ قطرِ جعبه
        final soft = hb * _kRevealSoft;
        // محورِ گرادیانت اونقدر بلند که کل صفحه رو بپوشونه.
        final r = math.max(hb * 1.5, rect.size.longestSide);
        final front = ui.lerpDouble(-hb - soft, hb + soft, p)!;
        double st(double v) => ((v + r) / (2 * r)).clamp(0.0, 1.0);
        return ui.Gradient.linear(
          c - u * r,
          c + u * r,
          [behind, behind, ahead, ahead],
          [0.0, st(front - soft), st(front + soft), 1.0],
        );
      },
      child: child,
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

  // دکمه‌ها و متن‌ها — ورودشون انیمیت شده. چیدمان مدرن: اول دکمه‌ی اصلی
  // (سفید با هاله‌ی نرم)، بعد لینک دوم، و آخرِ کار متن کوچیکِ قوانین.
  Widget _bottomBlock(BuildContext context, double t) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _reveal(
          t,
          _f(_tMoveEnd + _msBtnMainAt),
          _f(_tBtnMainEnd),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x59000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: SizedBox(
              height: 56,
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
                  // متن دکمه روی پس‌زمینه‌ی سفیده، پس تیره‌ی گرم.
                  foregroundColor: const Color(0xFF24201F),
                  elevation: 0,
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700),
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
        ),
        const SizedBox(height: 8),
        _reveal(
          t,
          _f(_tMoveEnd + _msBtnSecAt),
          _f(_tBtnSecEnd),
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
        // TODO: اگه صفحه‌ی قوانین/حریم خصوصی داری، به این متن لینک بده.
        _reveal(
          t,
          _f(_tMoveEnd + _msTextAt),
          _f(_tTextEnd),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'با زدن «ادامه» قوانین و سیاست حریم خصوصی رو می‌پذیری.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xCCFFFFFF),
                fontSize: 12.5,
                height: 1.6,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _Diag { topLeftToBottomRight, topRightToBottomLeft }

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