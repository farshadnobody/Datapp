import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../models/profile_models.dart';
import '../onboarding/onboarding_data.dart';
import '../widgets/discovery_profile_detail_sheet.dart';
import '../widgets/profile_safety_actions.dart';
import 'swipe_style.dart';

/// کارت پروفایل سبک تیندر.
///
/// - تپ روی نیمه‌ی راست/چپ کارت → عکس بعدی/قبلی (با نقطه‌های بالای کارت).
/// - پایین کارت همیشه اسم و سن هست؛ زیرش یه «بلوک اطلاعات» که با عوض شدن
///   عکس عوض می‌شه (بیو ← دنبال چی می‌گرده ← علاقه‌مندی‌ها ← مشخصات و سبک
///   زندگی)، فقط بلوک‌هایی که داده‌شون هست.
/// - فلش و دکمه‌ی ارسال بعد از باز شدنِ اطلاعات «روی خودِ کارت» می‌چسبن و با
///   اسکرولِ کارت حرکت می‌کنن (تو یه نقطه‌ی ثابتِ صفحه نمی‌مونن).
/// - اسم/سن/متنِ روی کارت فقط دو حالت دارن: کامل نمایان یا کامل هاید (با هر
///   اسکرولی هاید می‌شن؛ حالتِ نیمه‌هاید وجود نداره).
/// - آخرِ اطلاعات: اشتراک‌گذاری / مسدودسازی / گزارش.
/// - فلشِ هم‌ردیفِ اسم (مثل صفحه‌ی Preview Profile): اسکرولِ کارت اولش قفله و
///   اطلاعاتِ کامل مخفیه. با تپِ فلش قفل باز می‌شه، یه اسکرولِ کوچیک (هینت)
///   کارت رو یه‌کم هل می‌ده بالا و اطلاعاتِ چسبیده به کارت رو نشون می‌ده؛ از
///   اونجا به بعد کاربر آزادانه اسکرول می‌کنه. تپِ دوباره‌ی فلش (یا برگشتنِ
///   دستی به بالا) برمی‌گردونه به حالتِ اول، و این چرخه هر چندبار تکرار می‌شه.
class SwipeProfileCard extends StatefulWidget {
  final DiscoveryCandidate candidate;

  /// id → برچسب علاقه‌مندی‌ها (از /api/profile/options).
  final Map<String, String> interestLabels;

  /// id → متنِ سؤالِ پرامپت‌ها (برای نمایشِ جوابِ پرامپت‌ها زیرِ کارت).
  final Map<String, String> promptTextMap;

  /// علاقه‌مندی‌های خود کاربر؛ مشترک‌ها صورتی نشون داده می‌شن.
  final Set<String> myInterests;

  /// لحظه‌ی شروعِ باز شدنِ اطلاعات (true) یا شروعِ برگشت (false) صدا زده می‌شه؛
  /// صفحه‌ی سواپ با این، دکمه‌های لایک/رد/سوپرلایک/واگرد رو هاید/نمایان می‌کنه.
  final ValueChanged<bool>? onExpandedChanged;

  /// true = از لحظه‌ی باز شدن، false = بعد از تموم شدنِ کاملِ برگشت. صفحه‌ی
  /// سواپ با این کشیدنِ کارت رو خاموش/روشن می‌کنه تا با اسکرول تداخل نکنه.
  final ValueChanged<bool>? onSwipeLockChanged;

  /// دکمه‌ی ارسال پیام که بعد از باز شدنِ اطلاعات روی خودِ کارت می‌شینه.
  final VoidCallback? onSend;

  /// فقط تو حالتِ کامل (بعد از اونبوردینگ) دکمه‌ی ارسال وجود داره.
  final bool showSend;

  /// بعد از مسدودسازیِ موفق صدا زده می‌شه؛ صفحه‌ی سواپ کارت رو از Deck برمی‌داره.
  final VoidCallback? onBlocked;

  const SwipeProfileCard({
    super.key,
    required this.candidate,
    this.interestLabels = const {},
    this.promptTextMap = const {},
    this.myInterests = const {},
    this.onExpandedChanged,
    this.onSwipeLockChanged,
    this.onSend,
    this.showSend = true,
    this.onBlocked,
  });

  @override
  State<SwipeProfileCard> createState() => _SwipeProfileCardState();
}

enum _Block { bio, lookingFor, interests, basics }

class _SwipeProfileCardState extends State<SwipeProfileCard> with SingleTickerProviderStateMixin {
  int _index = 0;

  final ScrollController _scrollController = ScrollController();

  /// انیمیشنِ فلش: ۰ = کنارِ اسم، ۱ = پایین، هم‌ردیفِ دکمه‌ی ارسال.
  late final AnimationController _arrowCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  final GlobalKey _viewportKey = GlobalKey();

  /// روی خودِ متنِ اسم گذاشته می‌شه — مرکزِ فلش دقیقاً از روی مرکزِ همین باکس
  /// اندازه‌گیری می‌شه، نه یه باکسِ جدا با اندازه‌ی فرضی.
  final GlobalKey _nameKey = GlobalKey();

  /// مرکزِ عمودیِ اسم (نسبت به بالای کارتِ بدونِ اسکرول). چون ارتفاعِ بلوکِ
  /// زیرِ اسم عوض می‌شه، اندازه‌گیری می‌شه.
  double? _slotCenterY;

  /// عرض/ارتفاعِ ناحیه‌ی کارت (توی build پر می‌شه).
  double _w = 360;
  double _h = 600;

  static const double _arrowSize = 36;

  /// مرکزِ افقیِ دکمه‌ی واگرد تو نوارِ پایین (۵ اسلات با پدینگ ۷.۵).
  double get _rewindCenterX => 7.5 + (_w - 15) / 10;

  /// مرکزِ افقیِ دکمه‌ی ارسال تو نوارِ پایین (اسلاتِ پنجم از ۵ تا).
  double get _sendCenterX => 7.5 + (_w - 15) * 0.9;

  /// مرکزِ عمودیِ ردیفِ دکمه‌های پایین از بالای ناحیه.
  double get _buttonsCenterY => _h - SwipeMetrics.buttonsBottom - SwipeMetrics.bigButton / 2;

  /// تا فلش نخوره، اسکرولِ دستی قفله.
  bool _unlocked = false;

  /// فلش رو به پایینه (اطلاعات باز شده). فقط برای چرخشِ فلش و تصمیمِ تپِ بعدی.
  bool _expanded = false;

  /// وقتی انیمیشنِ باز/بسته شدن در جریانه، لیسنرِ اسکرول دخالت نمی‌کنه.
  bool _animating = false;

  /// شماره‌ی آخرین انیمیشن — تا تپِ سریع/انیمیشنِ قدیمی، حالتِ جدید رو خراب نکنه.
  int _animToken = 0;

  /// اسکرولِ هینتِ اولیه وقتی فلش می‌خوره (مثل Preview).
  static const double _peekNudge = 140;

  /// بیشتر از این مقدار اسکرول = متنِ روی کارت هاید و اطلاعات نمایان.
  static const double _hideThreshold = 1.0;

  /// فضای خالیِ آخرِ اسکرول (دکمه‌ها دیگه ثابت نیستن، پس فقط یه فاصله‌ی کم).
  static const double _bottomPad = 28;

  /// true = کاربر از بالای کارت اسکرول کرده: متنِ روی کارت کاملاً هاید و
  /// اطلاعاتِ زیرِ کارت کاملاً نمایان. فقط دو حالت داره، نه حالتِ وسط.
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _arrowCtrl.dispose();
    super.dispose();
  }

  double get _offset => _scrollController.hasClients ? _scrollController.offset : 0.0;

  /// گرادینت + اسم/سن/متنِ روی کارت: فقط بین «کامل نمایان» و «کامل هاید» جابه‌جا
  /// می‌شن. به یه مقدارِ بولین وصلن (نه به مقدارِ اسکرول)، پس هیچ‌وقت نمی‌شه
  /// نیمه‌هایدشون نگه داشت.
  Widget _fade(Widget child) => AnimatedOpacity(
        opacity: _scrolled ? 0 : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: child,
      );

  /// اگه کاربر خودش دستی برگشت بالا، فلش هم برمی‌گرده به حالتِ اول.
  void _onScroll() {
    // وسطِ انیمیشنِ فلش، خودِ انیمیشن وضعیتِ هاید/نمایان رو تعیین می‌کنه.
    if (_animating) return;
    final scrolled = _offset > _hideThreshold;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    if (_expanded && _offset <= 0) {
      setState(() {
        _expanded = false;
        _unlocked = false;
      });
      widget.onSwipeLockChanged?.call(false);
      // اول فلش برمی‌گرده سرِ جاش (کنارِ اسم)، بعد دکمه‌های لایک/رد/... ظاهر
      // می‌شن — نه هم‌زمان، تا وسطِ راه رویِ هم نیفتن.
      _arrowCtrl.reverse().whenCompleteOrCancel(() {
        if (mounted) widget.onExpandedChanged?.call(false);
      });
    }
  }

  void _onArrowTap() {
    HapticFeedback.lightImpact();
    // اگه باز شده و هنوز پایین‌تریم → ببند؛ در غیر این صورت → باز کن.
    if (_expanded && _offset >= 8) {
      _collapse();
    } else {
      _expand();
    }
  }

  Future<void> _expand() async {
    final token = ++_animToken;
    setState(() {
      _unlocked = true;
      _expanded = true;
      _scrolled = true;
    });
    widget.onExpandedChanged?.call(true);
    widget.onSwipeLockChanged?.call(true);
    _arrowCtrl.forward();
    _animating = true;
    // یه فریم صبر می‌کنیم تا فیزیکِ اسکرولِ باز شده اعمال بشه.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || token != _animToken) return;
    await _scrollController.animateTo(
      _peekNudge,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
    if (!mounted || token != _animToken) return;
    _animating = false;
  }

  Future<void> _collapse() async {
    final token = ++_animToken;
    setState(() {
      _expanded = false;
      _scrolled = false;
    });
    // اول فلش برمی‌گرده سرِ جاش (کنارِ اسم)، بعد دکمه‌های لایک/رد/... ظاهر
    // می‌شن — نه هم‌زمان، تا وسطِ راه رویِ هم نیفتن.
    unawaited(_arrowCtrl.reverse().whenCompleteOrCancel(() {
      if (mounted) widget.onExpandedChanged?.call(false);
    }));
    _animating = true;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
    if (!mounted || token != _animToken) return;
    _animating = false;
    // برگشت به حالتِ اول: اسکرول دوباره قفل، تا تپِ بعدیِ فلش دوباره باز کنه.
    setState(() => _unlocked = false);
    widget.onSwipeLockChanged?.call(false);
  }

  /// مرکزِ عمودیِ اسم رو نسبت به کارت اندازه می‌گیره (بدونِ اثرِ اسکرول) — فلش
  /// دقیقاً رویِ همین خط می‌شینه.
  void _measureSlot() {
    final name = _nameKey.currentContext?.findRenderObject();
    final vp = _viewportKey.currentContext?.findRenderObject();
    if (name is! RenderBox || vp is! RenderBox || !name.attached || !vp.attached) return;
    final c = name.localToGlobal(name.size.center(Offset.zero), ancestor: vp);
    final y0 = c.dy + _offset;
    if (_slotCenterY == null || (y0 - _slotCenterY!).abs() > 0.5) {
      setState(() => _slotCenterY = y0);
    }
  }

  List<String> get _photoUrls => widget.candidate.photos
      .map((p) => '$backendBaseUrl${p.url}')
      .toList();

  List<_Block> get _blocks {
    final c = widget.candidate;
    return [
      if (c.bio.trim().isNotEmpty) _Block.bio,
      if (c.lookingFor != null && _labelOf(kLookingForOptions, c.lookingFor!) != null)
        _Block.lookingFor,
      if (c.interests.isNotEmpty) _Block.interests,
      if (_basicsItems().isNotEmpty) _Block.basics,
    ];
  }

  void _onTapUp(TapUpDetails d, double width) {
    final count = _photoUrls.length;
    if (count <= 1) return;
    // صفحه راست‌به‌چپه (نقطه‌ها از راست شروع می‌شن): سمتِ راست = قبلی، چپ = بعدی.
    final goNext = d.localPosition.dx < width / 2;
    final next = _index + (goNext ? 1 : -1);
    if (next < 0 || next >= count) {
      HapticFeedback.selectionClick();
      return;
    }
    setState(() => _index = next);
  }

  @override
  Widget build(BuildContext context) {
    final urls = _photoUrls;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measureSlot();
    });
    // خودِ کارت (نه یه صفحه‌ی جدا) اسکرول می‌شه: کارت به اندازه‌ی کلِ فضای Deck
    // اولین آیتمِ یه Column‌ـه و اطلاعاتِ کامل درست زیرش. تا فلش نخوره اسکرول
    // قفله و اطلاعات هم مخفیه.
    return LayoutBuilder(builder: (context, viewport) {
      _w = viewport.maxWidth;
      _h = viewport.maxHeight;
      return Stack(
        key: _viewportKey,
        fit: StackFit.expand,
        children: [
          // وقتی اطلاعات نمایش داده می‌شه پشتِ کارت کاملاً مات می‌شه تا کارتِ
          // بعدی از زیرش دیده نشه. تو حالتِ اول (بدونِ اسکرول) شفافه، تا
          // گوشه‌های گردِ پایینِ کارت مثل قبل باشه.
          AnimatedBuilder(
            animation: _scrollController,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: _unlocked ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: _bottomPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // فلش و دکمه‌ی ارسال جزوِ همین بخش‌ان، پس با اسکرولِ کارت
                  // حرکت می‌کنن.
                  SizedBox(
                    height: viewport.maxHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(SwipeMetrics.cardRadius),
                            ),
                            child: _buildCard(urls),
                          ),
                        ),
                        _buildArrow(),
                        if (widget.showSend) _buildSendButton(),
                      ],
                    ),
                  ),
                  // اطلاعات درست زیرِ کارت؛ تا وقتی اسکرول نشده مخفیه و با
                  // اولین اسکرول کامل نمایان می‌شه.
                  const SizedBox(height: 12),
                  AnimatedOpacity(
                    opacity: _scrolled ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DiscoveryProfileDetailSheet(
                          candidate: widget.candidate,
                          promptTextMap: widget.promptTextMap,
                          interestLabelMap: widget.interestLabels,
                        ),
                        ProfileSafetyActions(
                          publicId: widget.candidate.publicId,
                          name: widget.candidate.name,
                          onBlocked: widget.onBlocked,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            builder: (context, child) => ColoredBox(
              color: (_unlocked || _offset > 0) ? SwipeColors.black : Colors.transparent,
              child: child,
            ),
          ),
        ],
      );
    });
  }

  /// دکمه‌ی ارسال — بعد از باز شدنِ اطلاعات روی کارت می‌شینه و با اسکرولِ کارت
  /// حرکت می‌کنه. دقیقاً روی جای دکمه‌ی ارسالِ نوارِ پایینه؛ نوارِ پایین تا
  /// وقتی کارت بازه اون رو هاید می‌کنه، پس هیچ‌وقت دوتا دیده نمی‌شن.
  Widget _buildSendButton() {
    const size = SwipeMetrics.smallButton;
    return Positioned(
      left: _sendCenterX - size / 2,
      top: _buttonsCenterY - size / 2,
      child: IgnorePointer(
        ignoring: !_unlocked,
        child: AnimatedOpacity(
          opacity: _unlocked ? 1 : 0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: _CardSendButton(size: size, onTap: widget.onSend),
        ),
      ),
    );
  }

  /// فلش — روی خودِ کارت می‌چسبه (با اسکرول حرکت می‌کنه). کنارِ اسم شروع می‌شه و با تپ،
  /// با انیمیشن میاد پایین، هم‌ردیفِ دکمه‌ی ارسال، و هم‌اندازه‌ی اون (بزرگ) می‌شه.
  Widget _buildArrow() {
    final slotY = _slotCenterY;
    if (slotY == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _arrowCtrl,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_arrowCtrl.value);
        final size = _arrowSize + (SwipeMetrics.smallButton - _arrowSize) * t;
        final cy = slotY + (_buttonsCenterY - slotY) * t;
        return Positioned(
          left: _rewindCenterX - size / 2,
          top: cy - size / 2,
          child: _OpenProfileButton(size: size, down: _expanded, onTap: _onArrowTap),
        );
      },
    );
  }

  Widget _buildCard(List<String> urls) {
    return LayoutBuilder(builder: (context, constraints) {
      return ColoredBox(
        color: SwipeColors.cardBase,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildPhoto(urls),
            // گرادیانت بالا (زیر نقطه‌ها/بنر)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 96,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xB3000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
            ),
            // گرادیانت پایین — تا رنگ ته کارت (زیر دکمه‌ها) ادامه داره؛ با باز
            // شدنِ اطلاعات محو می‌شه.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: constraints.maxHeight * 0.6,
              child: IgnorePointer(
                child: _fade(
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 0.55, 0.85],
                        colors: [
                          Color(0x00101113),
                          Color(0xB3101113),
                          SwipeColors.cardBase,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // ناحیه‌ی تپ برای عوض کردن عکس
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _onTapUp(d, constraints.maxWidth),
              ),
            ),
            // نقطه‌های عکس‌ها
            if (urls.length > 1)
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(child: _PhotoDots(count: urls.length, index: _index)),
                ),
              ),
            // اطلاعات پایین کارت
            Positioned(
              left: SwipeMetrics.infoSide,
              right: SwipeMetrics.infoSide,
              bottom: SwipeMetrics.infoBottom,
              child: _buildInfo(),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildPhoto(List<String> urls) {
    if (urls.isEmpty) {
      return Container(
        color: const Color(0xFF1B1C1F),
        child: const Center(
          child: Icon(Icons.person, size: 110, color: Color(0xFF3A3B40)),
        ),
      );
    }
    return Image.network(
      urls[_index.clamp(0, urls.length - 1)],
      fit: BoxFit.cover,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const ColoredBox(color: Color(0xFF1B1C1F));
      },
      errorBuilder: (context, error, stack) => Container(
        color: const Color(0xFF1B1C1F),
        child: const Center(
          child: Icon(Icons.broken_image_outlined, size: 56, color: Color(0xFF55565B)),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // اطلاعات
  // ---------------------------------------------------------------------

  Widget _buildInfo() {
    final c = widget.candidate;
    final blocks = _blocks;
    final block = blocks.isEmpty ? null : blocks[_index % blocks.length];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_pillLabel(c.activityStatus) != null)
          IgnorePointer(child: _fade(_StatusPill(status: c.activityStatus!))),
        const SizedBox(height: 8),
        // فلش هم‌ردیفِ اسم (وسط‌چینِ عمودی).
        Row(
          children: [
            Expanded(
              child: IgnorePointer(
                child: _fade(Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: c.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text: '  ${c.age}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w400,
                        color: Color(0xFFEDEDED),
                      ),
                    ),
                  ]),
                  key: _nameKey,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    height: 1.2,
                  ),
                )),
              ),
            ),
            const SizedBox(width: 8),
            // جای خالیِ فلش (فلشِ اصلی شناوره و روی همین نقطه میشینه). چپ‌فاصله
            // داده شده تا مرکزش با مرکزِ دکمه‌ی واگرد یکی باشه.
            Padding(
              padding: EdgeInsets.only(
                left: (_rewindCenterX - _arrowSize / 2 - SwipeMetrics.infoSide).clamp(0.0, 200.0).toDouble(),
              ),
              child: SizedBox(width: _arrowSize, height: _arrowSize),
            ),
          ],
        ),
        if (block != null) ...[
          const SizedBox(height: 8),
          IgnorePointer(child: _fade(_buildBlock(block))),
        ],
      ],
    );
  }

  Widget _buildBlock(_Block block) {
    final c = widget.candidate;
    switch (block) {
      case _Block.bio:
        return Text(
          c.bio.trim(),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        );

      case _Block.lookingFor:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _BlockHeader(icon: Icons.search, text: 'دنبال چی می‌گرده'),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: Text(
                _labelOf(kLookingForOptions, c.lookingFor!) ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );

      case _Block.interests:
        final ids = [...c.interests];
        // مشترک‌ها اول
        ids.sort((a, b) {
          final sa = widget.myInterests.contains(a) ? 0 : 1;
          final sb = widget.myInterests.contains(b) ? 0 : 1;
          return sa.compareTo(sb);
        });
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _BlockHeader(icon: Icons.interests, text: 'علاقه‌مندی‌ها'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ids
                  .take(8)
                  .map((id) => _Chip(
                        text: _interestLabel(id),
                        highlighted: widget.myInterests.contains(id),
                      ))
                  .toList(),
            ),
          ],
        );

      case _Block.basics:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _BlockHeader(icon: Icons.label, text: 'مشخصات و سبک زندگی'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _basicsItems()
                  .take(8)
                  .map((e) => _Chip(text: e.$2, icon: e.$1))
                  .toList(),
            ),
          ],
        );
    }
  }

  String _interestLabel(String id) {
    final fromApi = widget.interestLabels[id];
    if (fromApi != null) return fromApi;
    for (final cat in kInterestCategories) {
      final l = _labelOf(cat.items, id);
      if (l != null) return l;
    }
    return id;
  }

  /// (آیکون، برچسب) — به ترتیب نمایش تو کارت.
  List<(IconData, String)> _basicsItems() {
    final c = widget.candidate;
    final out = <(IconData, String)>[];

    if (c.educationLevel != null) {
      final l = _labelOf(kEducationOptions, c.educationLevel!);
      if (l != null) out.add((Icons.school_outlined, l));
    }

    void addFrom(List<OptionCategory> cats, Map<String, String> values) {
      for (final cat in cats) {
        final v = values[cat.id];
        if (v == null) continue;
        final l = _labelOf(cat.items, v);
        if (l == null) continue;
        out.add((_iconFor(cat.id, v), l));
      }
    }

    // ترتیب مثل اسکرین‌شات: مشروب، سیگار، ورزش، حیوون، ارتباط، ... ، برج
    final lifestyleOrder = ['drinking', 'smoking', 'workout', 'pets'];
    for (final id in lifestyleOrder) {
      addFrom(kLifestyleCategories.where((e) => e.id == id).toList(), c.lifestyle);
    }
    for (final id in ['communication', 'love_language', 'zodiac']) {
      addFrom(kAboutYouCategories.where((e) => e.id == id).toList(), c.aboutYou);
    }
    return out;
  }

  IconData _iconFor(String category, String value) {
    switch (category) {
      case 'drinking':
        return Icons.wine_bar_outlined;
      case 'smoking':
        return value == 'non_smoker' ? Icons.smoke_free : Icons.smoking_rooms;
      case 'workout':
        return Icons.fitness_center;
      case 'pets':
        return Icons.pets;
      case 'communication':
        return Icons.chat_bubble_outline;
      case 'love_language':
        return Icons.favorite_border;
      case 'zodiac':
        return Icons.nightlight_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  static String? _labelOf(List<OptionItem> items, String id) {
    for (final i in items) {
      if (i.id == id) return i.label;
    }
    return null;
  }

  static String? _pillLabel(String? status) {
    switch (status) {
      case 'new':
        return 'تازه اومده';
      case 'active':
        return 'فعال';
      case 'recent':
        return 'اخیراً فعال';
      default:
        return null;
    }
  }
}

// -----------------------------------------------------------------------
// اجزای کوچیک
// -----------------------------------------------------------------------

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = _SwipeProfileCardState._pillLabel(status) ?? '';
    final showDot = status != 'new';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: SwipeColors.pillBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: SwipeColors.activeGreen,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1B1B1D),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockHeader extends StatelessWidget {
  final IconData icon;
  final String text;
  const _BlockHeader({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Colors.white),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool highlighted;
  const _Chip({required this.text, this.icon, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final fg = highlighted ? const Color(0xFF1C1C1E) : Colors.white;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: icon == null ? 14 : 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted ? SwipeColors.chipPink : SwipeColors.chipDark,
        borderRadius: BorderRadius.circular(22),
        border: highlighted ? null : Border.all(color: SwipeColors.chipBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: fg),
            const SizedBox(width: 7),
          ],
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// نقطه‌های کوچیک بالای کارت (فعلی سفید، بقیه خاکستری).
class _PhotoDots extends StatelessWidget {
  final int count;
  final int index;
  const _PhotoDots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    final shown = count > 9 ? 9 : count;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < shown; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 8,
            height: 3,
            decoration: BoxDecoration(
              color: i == index ? Colors.white : const Color(0x66FFFFFF),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}

/// دکمه‌ی ارسالِ روی کارت — هم‌شکلِ دکمه‌ی ارسالِ نوارِ پایین.
class _CardSendButton extends StatelessWidget {
  final double size;
  final VoidCallback? onTap;
  const _CardSendButton({required this.size, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              onTap!();
            },
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: SwipeColors.buttonBg,
          shape: BoxShape.circle,
          border: Border.all(color: SwipeColors.buttonBorder, width: 1),
        ),
        child: const Icon(Icons.near_me, size: 22, color: SwipeColors.superLikeSoft),
      ),
    );
  }
}

/// دکمه‌ی فلشِ کنارِ اسم — دایره‌ی مشکی با شورونِ ضخیم؛ با تپ ۱۸۰ درجه می‌چرخه.
class _OpenProfileButton extends StatelessWidget {
  final double size;
  final bool down;
  final VoidCallback onTap;
  const _OpenProfileButton({required this.size, required this.down, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle,
          border: Border.all(color: SwipeColors.buttonBorder, width: 1),
        ),
        alignment: Alignment.center,
        child: AnimatedRotation(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          turns: down ? 0.5 : 0,
          // شورون هم با بزرگ شدنِ دکمه متناسب بزرگ می‌شه.
          child: SizedBox(
            width: size / 2,
            height: size / 2,
            child: const CustomPaint(painter: _ChevronPainter()),
          ),
        ),
      ),
    );
  }
}

/// شورونِ رو به بالا با خطِ ضخیم و سرِ گرد.
class _ChevronPainter extends CustomPainter {
  const _ChevronPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.1, size.height * 0.65)
      ..lineTo(size.width * 0.5, size.height * 0.3)
      ..lineTo(size.width * 0.9, size.height * 0.65);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
