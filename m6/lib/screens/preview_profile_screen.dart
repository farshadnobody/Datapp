import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../models/profile_models.dart';
import '../onboarding/onboarding_data.dart';
import '../style/app_colors.dart';
import '../swipe/swipe_style.dart';
import '../widgets/my_profile_detail_sheet.dart';

/// «Preview Profile» — یه صفحه‌ی پیوسته (مثل اسکرولِ یه صفحه‌ی وب): کارتِ
/// عکس **دقیقاً هم‌اندازه‌ی کارتِ صفحه‌ی سواپ** (تمام‌عرض، از زیرِ هدر تا جایی
/// که تو سواپ نوارِ پایین شروع می‌شه، گوشه‌های پایینِ گرد) با اسم و سن تو
/// همون محلِ کارتِ سواپ؛ و بلافاصله زیرش، در همون فلوی عادی، اطلاعاتِ کامل
/// پروفایل.
///
/// اسکرول اولش قفله و اطلاعات مخفیه. با تپِ فلشِ کنار اسم: قفل باز می‌شه و
/// یه اسکرولِ کوچیک (هینت) می‌خوره که کارت رو یه‌کم هل بده بالا و اطلاعاتِ
/// چسبیده به کارت رو نشون بده — از اونجا به بعد خودِ کاربر آزادانه اسکرول
/// می‌کنه. تپِ دوباره‌ی فلش (یا برگشتنِ دستی به بالا) برمی‌گردونه به حالتِ
/// اول، و این چرخه هر چندبار قابل تکراره.
class PreviewProfileScreen extends StatefulWidget {
  final MyProfile profile;
  final Map<String, String> promptTextMap;
  final Map<String, String> interestLabelMap;

  const PreviewProfileScreen({
    super.key,
    required this.profile,
    required this.promptTextMap,
    required this.interestLabelMap,
  });

  @override
  State<PreviewProfileScreen> createState() => _PreviewProfileScreenState();
}

enum _Block { bio, lookingFor, interests, basics }

class _PreviewProfileScreenState extends State<PreviewProfileScreen> {
  int _index = 0;

  final ScrollController _scrollController = ScrollController();

  /// تا فلش نخوره، اسکرولِ دستی قفله.
  bool _unlocked = false;

  /// فلش رو به پایینه (اطلاعات باز شده). فقط برای چرخشِ فلش و تصمیمِ تپِ بعدی.
  bool _expanded = false;

  /// وقتی انیمیشنِ باز/بسته شدن در جریانه، لیسنرِ اسکرول دخالت نمی‌کنه.
  bool _animating = false;

  /// شماره‌ی آخرین انیمیشن — تا تپِ سریع/انیمیشنِ قدیمی، حالتِ جدید رو خراب نکنه.
  int _animToken = 0;

  static const double _peekNudge = 140; // اسکرولِ هینتِ اولیه وقتی فلش می‌خوره.

  /// چند پیکسل اسکرول تا اطلاعات کامل ظاهر بشه (قبلش محو/مخفیه).
  static const double _revealDistance = 32;

  /// فاصله‌ی کارتِ عکس از هدر (کارت این‌قدر پایین‌تر شروع می‌شه).
  static const double _cardTopGap = 36;

  /// کارت این‌قدر هم از پایین کوتاه‌تر می‌شه.
  static const double _cardBottomCut = 16;

  /// فاصله‌ی اسم/متن تا لبه‌ی پایینِ کارت. مقدارش طوری کم شده که اسم و سن
  /// همون فاصله‌ی قبلی رو از بالای کارت حفظ کنن (کارت کوتاه‌تر شده).
  static const double _infoBottom = SwipeMetrics.infoBottom - _cardTopGap - _cardBottomCut;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  double get _offset => _scrollController.hasClients ? _scrollController.offset : 0.0;

  /// اگه کاربر خودش دستی برگشت بالا، فلش هم برمی‌گرده به حالتِ اول.
  void _onScroll() {
    if (_expanded && !_animating && _offset < 8) {
      setState(() => _expanded = false);
    }
  }

  List<String> get _urls => widget.profile.photos.map((p) => '$backendBaseUrl${p.url}').toList();

  List<_Block> get _blocks {
    final p = widget.profile;
    return [
      if (p.bio.trim().isNotEmpty) _Block.bio,
      if (p.lookingFor != null && optionLabel(kLookingForOptions, p.lookingFor) != null) _Block.lookingFor,
      if (p.interests.isNotEmpty) _Block.interests,
      if (_basicsItems().isNotEmpty) _Block.basics,
    ];
  }

  /// (آیکون، برچسب) — همون منطق _basicsItems تو کارت‌های سواپ، برای یکدستی.
  List<(IconData, String)> _basicsItems() {
    final p = widget.profile;
    final out = <(IconData, String)>[];
    final education = optionLabel(kEducationOptions, p.educationLevel);
    if (education != null) out.add((Icons.school_outlined, education));

    void addFrom(List<OptionCategory> cats, Map<String, String> values) {
      for (final cat in cats) {
        final v = values[cat.id];
        if (v == null) continue;
        final l = optionLabel(cat.items, v);
        if (l == null) continue;
        out.add((_iconFor(cat.id, v), l));
      }
    }

    final lifestyleOrder = ['drinking', 'smoking', 'workout', 'pets'];
    for (final id in lifestyleOrder) {
      addFrom(kLifestyleCategories.where((e) => e.id == id).toList(), p.lifestyle);
    }
    for (final id in ['communication', 'love_language', 'zodiac']) {
      addFrom(kAboutYouCategories.where((e) => e.id == id).toList(), p.aboutYou);
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

  String _interestLabel(String id) {
    final fromApi = widget.interestLabelMap[id];
    if (fromApi != null) return fromApi;
    for (final cat in kInterestCategories) {
      final l = optionLabel(cat.items, id);
      if (l != null) return l;
    }
    return id;
  }

  void _onTapUp(TapUpDetails d, double width) {
    final count = _urls.length;
    if (count <= 1) return;
    // سمتِ راستِ عکس = قبلی، سمتِ چپ = بعدی (هم‌جهت با آر‌تی‌الِ صفحه).
    final goNext = d.localPosition.dx < width / 2;
    final next = _index + (goNext ? 1 : -1);
    if (next < 0 || next >= count) {
      HapticFeedback.selectionClick();
      return;
    }
    setState(() => _index = next);
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
    });
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
    setState(() => _expanded = false);
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
  }

  Widget _buildBlock(_Block block) {
    final p = widget.profile;
    switch (block) {
      case _Block.bio:
        return Text(
          p.bio.trim(),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w500, height: 1.35),
        );

      case _Block.lookingFor:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _BlockHeader(icon: Icons.search, text: 'دنبال چی می‌گردی'),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: Text(optionLabel(kLookingForOptions, p.lookingFor) ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
            ),
          ],
        );

      case _Block.interests:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _BlockHeader(icon: Icons.interests, text: 'علاقه‌مندی‌ها'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: p.interests.take(8).map((id) => _Chip(text: _interestLabel(id))).toList(),
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
              children: _basicsItems().take(8).map((e) => _Chip(text: e.$2, icon: e.$1)).toList(),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final urls = _urls;
    final blocks = _blocks;
    final block = blocks.isEmpty ? null : blocks[_index % blocks.length];
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // هم‌ارتفاعِ هدرِ صفحه‌ی سواپ، تا کارت دقیقاً از همون‌جا شروع بشه.
              SizedBox(
                height: SwipeMetrics.headerHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_forward, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Text('پیش‌نمایش پروفایل', style: TextStyle(color: Colors.white, fontSize: 17)),
                  ]),
                ),
              ),
              Expanded(
                child: LayoutBuilder(builder: (context, viewport) {
                  // تو سواپ، کارت بین هدر و نوارِ پایین (۶۴ + safe-area) قرار
                  // می‌گیره. این‌جا نوار نداریم، پس همون مقدار رو از ارتفاعِ
                  // در دسترس کم می‌کنیم تا کارت عیناً هم‌اندازه بشه.
                  final cardHeight = (viewport.maxHeight -
                          SwipeMetrics.navHeight -
                          bottomInset -
                          _cardTopGap -
                          _cardBottomCut)
                      .clamp(320.0, double.infinity)
                      .toDouble();
                  return SingleChildScrollView(
                    controller: _scrollController,
                    physics: _unlocked ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.only(bottom: 28 + bottomInset),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // فاصله‌ی بین هدر و کارت.
                        const SizedBox(height: _cardTopGap),
                        // کارت: تمام‌عرض، هر چهار گوشه گرد.
                        SizedBox(
                          height: cardHeight,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.all(Radius.circular(SwipeMetrics.cardRadius)),
                            child: _PhotoCard(
                              urls: urls,
                              index: _index,
                              name: widget.profile.name,
                              age: widget.profile.age,
                              block: block,
                              buildBlock: block == null ? null : () => _buildBlock(block),
                              infoBottom: _infoBottom,
                              arrowDown: _expanded,
                              onArrowTap: _onArrowTap,
                              onTapUp: _onTapUp,
                            ),
                          ),
                        ),
                        // اطلاعات درست زیرِ کارت (فاصله‌ی ثابت، بدون اسپیسرِ خالی).
                        // تا وقتی اسکرول نشده مخفیه و با اسکرول محو→آشکار می‌شه؛
                        // پس قبل از زدنِ فلش چیزی از اون زیرِ کارت دیده نمی‌شه.
                        const SizedBox(height: 12),
                        AnimatedBuilder(
                          animation: _scrollController,
                          // بدون پدینگِ افقی: باکس‌ها هم‌عرضِ کارتِ عکس‌ان.
                          child: MyProfileDetailSheet(
                            profile: widget.profile,
                            promptTextMap: widget.promptTextMap,
                            interestLabelMap: widget.interestLabelMap,
                          ),
                          builder: (context, child) => Opacity(
                            opacity: (_offset / _revealDistance).clamp(0.0, 1.0).toDouble(),
                            child: child,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------
// اجزای کوچیک
// -----------------------------------------------------------------------

/// کارتِ عکس — عکس + گرادینت‌های بالا/پایین + اسم/فلش/بلوکِ اطلاعات روش،
/// با همون گرادینت و همون فاصله‌های SwipeProfileCard (SwipeMetrics)، تا اسم و
/// سن دقیقاً تو همون محلِ کارتِ سواپ بشینه. چون خودِ صفحه (نه این کارت)
/// اسکرول می‌شه، این ویجت فقط یه آیتمِ اولِ یه Column معمولیه.
class _PhotoCard extends StatelessWidget {
  final List<String> urls;
  final int index;
  final String name;
  final int age;
  final _Block? block;
  final Widget Function()? buildBlock;
  final double infoBottom;
  final bool arrowDown;
  final VoidCallback onArrowTap;
  final void Function(TapUpDetails details, double width) onTapUp;

  const _PhotoCard({
    required this.urls,
    required this.index,
    required this.name,
    required this.age,
    required this.block,
    required this.buildBlock,
    required this.infoBottom,
    required this.arrowDown,
    required this.onArrowTap,
    required this.onTapUp,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return ColoredBox(
        color: SwipeColors.cardBase,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (urls.isEmpty)
              Container(
                color: const Color(0xFF1B1C1F),
                child: const Center(child: Icon(Icons.person, size: 110, color: Color(0xFF3A3B40))),
              )
            else
              Image.network(
                urls[index.clamp(0, urls.length - 1)],
                fit: BoxFit.cover,
                gaplessPlayback: true,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const ColoredBox(color: Color(0xFF1B1C1F));
                },
                errorBuilder: (context, error, stack) => Container(
                  color: const Color(0xFF1B1C1F),
                  child: const Center(child: Icon(Icons.broken_image_outlined, size: 56, color: Color(0xFF55565B))),
                ),
              ),

            // گرادینتِ بالا (زیرِ نوارِ عکس‌ها) — مثل سواپ.
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

            // گرادینتِ پایین — مثل سواپ، ولی بلندتر تا پشتِ متن‌ها رو کامل بگیره.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: constraints.maxHeight * 0.75,
              child: const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.55, 0.85],
                      colors: [Color(0x00101113), Color(0xB3101113), SwipeColors.cardBase],
                    ),
                  ),
                ),
              ),
            ),

            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => onTapUp(d, constraints.maxWidth),
              ),
            ),

            if (urls.length > 1)
              Positioned(
                top: 10,
                left: 12,
                right: 12,
                child: IgnorePointer(
                  child: Row(
                    children: List.generate(urls.length, (i) {
                      return Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: i == index ? Colors.white : const Color(0x66FFFFFF),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),

            // اسم/سن/فلش/بلوک — همون فاصله‌های کارتِ سواپ از کنار و پایین.
            Positioned(
              left: SwipeMetrics.infoSide,
              right: SwipeMetrics.infoSide,
              bottom: infoBottom,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: IgnorePointer(
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              TextSpan(
                                text: '  $age',
                                style: const TextStyle(fontWeight: FontWeight.w400, color: Color(0xFFEDEDED)),
                              ),
                            ]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 30, height: 1.2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _OpenProfileButton(down: arrowDown, onTap: onArrowTap),
                    ],
                  ),
                  if (buildBlock != null) ...[
                    const SizedBox(height: 8),
                    // مثل سواپ: تپ روی بلوک به عوض شدنِ عکس می‌رسه.
                    IgnorePointer(child: buildBlock!()),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    });
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
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final IconData? icon;
  const _Chip({required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: icon == null ? 14 : 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppDark.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: Colors.white),
            const SizedBox(width: 7),
          ],
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500, height: 1.2)),
        ],
      ),
    );
  }
}

/// دکمه‌ی فلشِ روی عکس — دایره‌ی نیمه‌شفاف؛ با تپ ۱۸۰ درجه می‌چرخه.
/// آیکونِ شورونِ ساده (بدون دمِ فلش) که تیندر هم استفاده می‌کنه.
class _OpenProfileButton extends StatelessWidget {
  final bool down;
  final VoidCallback onTap;
  const _OpenProfileButton({required this.down, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(color: Color(0x33FFFFFF), shape: BoxShape.circle),
        child: AnimatedRotation(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          turns: down ? 0.5 : 0,
          child: const Icon(Icons.expand_less, size: 22, color: Colors.white),
        ),
      ),
    );
  }
}
