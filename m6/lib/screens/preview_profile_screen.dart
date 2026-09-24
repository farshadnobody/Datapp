import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../models/profile_models.dart';
import '../onboarding/onboarding_data.dart';
import '../style/app_colors.dart';
import '../widgets/my_profile_detail_sheet.dart';

/// «Preview Profile» — یه صفحه‌ی پیوسته (مثل اسکرولِ یه صفحه‌ی وب): کارتِ
/// عکس با نسبتِ ثابت (کمی بلندتر از فریمِ استاندارد آپلود که ۴:۵ـه — عیناً
/// اندازه‌ای که تو MatchProfileScreen هم استفاده شده) و بلافاصله زیرش،
/// در همون فلوی عادی (نه روی هم!)، اطلاعاتِ کامل پروفایل.
///
/// اسکرول اولش قفله. با تپِ فلشِ کنار اسم: قفل باز می‌شه و یه اسکرولِ کوچیک
/// (هینت) می‌خوره که کارت رو یه‌کم هل بده بالا و نشون بده ادامه‌ش هست —
/// از اونجا به بعد خودِ کاربر آزادانه اسکرول می‌کنه. تپِ دوباره‌ی همون فلش
/// (وقتی برگرده بالا و دوباره دیده بشه) برمی‌گردونه به حالت اول.
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
  bool _unlocked = false; // تا فلش نخوره، اسکرولِ دستی قفله.
  bool _arrowDown = false; // چرخشِ فلشِ روی عکس.

  static const double _peekNudge = 140; // اسکرولِ هینتِ اولیه وقتی فلش می‌خوره.

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    if (!_unlocked) {
      setState(() {
        _unlocked = true;
        _arrowDown = true;
      });
      _scrollController.animateTo(_peekNudge,
          duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    } else {
      _collapse();
    }
  }

  void _collapse() {
    HapticFeedback.lightImpact();
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    setState(() => _arrowDown = false);
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_forward, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Text('پیش‌نمایش پروفایل', style: TextStyle(color: Colors.white, fontSize: 17)),
                ]),
              ),
              Expanded(
                child: LayoutBuilder(builder: (context, viewport) {
                  // ارتفاعِ واقعیِ قابل‌مشاهده (پدینگِ بالا/پایینِ اسکرول‌ویو رو
                  // هم کم می‌کنیم) — تا بفهمیم زیرِ کارتِ عکس، قبل از اسکرول،
                  // چقدر فضای خالی لازمه که هیچی از اطلاعاتِ پروفایل دیده نشه.
                  const verticalPadding = 4.0 + 28.0;
                  final availableHeight = viewport.maxHeight - verticalPadding;
                  return SingleChildScrollView(
                    controller: _scrollController,
                    physics: _unlocked ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    child: LayoutBuilder(builder: (context, content) {
                      final photoHeight = content.maxWidth * 4 / 3; // نسبتِ ۳:۴
                      final spacer = (availableHeight - photoHeight).clamp(0.0, double.infinity);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: AspectRatio(
                              aspectRatio: 3 / 4,
                              child: _PhotoCard(
                                urls: urls,
                                index: _index,
                                name: widget.profile.name,
                                age: widget.profile.age,
                                block: block,
                                buildBlock: block == null ? null : () => _buildBlock(block),
                                arrowDown: _arrowDown,
                                onArrowTap: _onArrowTap,
                                onTapUp: _onTapUp,
                              ),
                            ),
                          ),
                          // این فاصله‌ی خالی همون چیزیه که تا قبل از زدنِ فلش،
                          // اطلاعاتِ پروفایل رو کاملاً بیرون از دیدِ اولیه نگه
                          // می‌داره — بدون این، چون کارتِ عکس دیگه تمامِ صفحه
                          // رو پر نمی‌کنه، اطلاعات از همون اول جزئی دیده می‌شد.
                          SizedBox(height: spacer),
                          const SizedBox(height: 18),
                          MyProfileDetailSheet(
                            profile: widget.profile,
                            promptTextMap: widget.promptTextMap,
                            interestLabelMap: widget.interestLabelMap,
                          ),
                        ],
                      );
                    }),
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

/// کارتِ عکس — نسبتِ ثابت (۳:۴)، عکس + گرادینتِ مشکیِ پایین + اسم/فلش/بلوکِ
/// اطلاعات روش. چون خودِ صفحه (نه این کارت) اسکرول می‌شه، این ویجت فقط یه
/// آیتمِ اولِ یه Column معمولیه — عیناً MatchProfileScreen.
class _PhotoCard extends StatelessWidget {
  final List<String> urls;
  final int index;
  final String name;
  final int age;
  final _Block? block;
  final Widget Function()? buildBlock;
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
    required this.arrowDown,
    required this.onArrowTap,
    required this.onTapUp,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (urls.isEmpty)
            Container(
              color: AppDark.cardAlt,
              child: const Center(child: Icon(Icons.person, size: 110, color: AppDark.muted)),
            )
          else
            Image.network(urls[index.clamp(0, urls.length - 1)], fit: BoxFit.cover, gaplessPlayback: true),

          // گرادینتِ مشکیِ پایین — طولانی‌تر از قبل (نه با کش‌اومدنِ عکس؛
          // فقط سهمِ خودِ گرادینت از ارتفاعِ کارت بیشتر شده).
          IgnorePointer(
            child: Container(
              height: constraints.maxHeight * 0.6,
              alignment: Alignment.bottomCenter,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.45, 1.0],
                  colors: [Color(0x00000000), Color(0x99000000), Color(0xFF000000)],
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

          Positioned(
            left: 20,
            right: 16,
            bottom: 18,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('$name  $age',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    _OpenProfileButton(down: arrowDown, onTap: onArrowTap),
                  ],
                ),
                if (buildBlock != null) ...[
                  const SizedBox(height: 8),
                  buildBlock!(),
                ],
              ],
            ),
          ),
        ],
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
