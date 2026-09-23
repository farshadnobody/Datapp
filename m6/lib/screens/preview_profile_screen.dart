import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../models/profile_models.dart';
import '../onboarding/onboarding_data.dart';
import '../style/app_colors.dart';
import '../widgets/my_profile_detail_sheet.dart';

/// «Preview Profile» — عیناً رفتار پروفایل تو تیندر: باکس عکس تمام‌قد با
/// گرادینت مشکی پایین، اسم و «بلوک اطلاعات» (بیو ← دنبال چی می‌گردی ←
/// علاقه‌مندی‌ها ← مشخصات) روی همون گرادینت. اطلاعات کامل پروفایل
/// (MyProfileDetailSheet) به‌صورت پیش‌فرض دیده نمی‌شه؛ فقط با زدن فلش کنار
/// اسم، از پایین به شکل یه شیت میاد روی عکس — همزمان اسم/گرادینت/بلوکِ روی
/// عکس محو می‌شن و به‌جاش بالای شیت یه هدر با اسم و فلشِ روبه‌پایین (برای
/// بستن) نشون داده می‌شه.
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
  bool _expanded = false;

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
    // همون جهتِ کارت‌های سواپ (SwipeProfileCard): نیمه‌ی راست = بعدی.
    final goNext = d.localPosition.dx >= width / 2;
    final next = _index + (goNext ? 1 : -1);
    if (next < 0 || next >= count) {
      HapticFeedback.selectionClick();
      return;
    }
    setState(() => _index = next);
  }

  void _toggleExpanded() {
    HapticFeedback.lightImpact();
    setState(() => _expanded = !_expanded);
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
        // پس‌زمینه‌ی خاکستریِ تیره پشت کارت مشکیِ عکس.
        backgroundColor: AppDark.cardAlt,
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
              // باکس عکس — تمام ارتفاعِ باقی‌مونده‌ی صفحه، دقیقاً مثل تیندر.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LayoutBuilder(builder: (context, constraints) {
                      final sheetHeight = constraints.maxHeight * 0.76;
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          if (urls.isEmpty)
                            Container(
                              color: Colors.black,
                              child: const Center(child: Icon(Icons.person, size: 110, color: AppDark.muted)),
                            )
                          else
                            Image.network(urls[_index.clamp(0, urls.length - 1)],
                                fit: BoxFit.cover, gaplessPlayback: true),

                          // گرادینت مشکیِ پایین — محو می‌شه وقتی شیتِ اطلاعات باز می‌شه.
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 260),
                            opacity: _expanded ? 0 : 1,
                            child: IgnorePointer(
                              child: Container(
                                height: constraints.maxHeight * 0.46,
                                alignment: Alignment.bottomCenter,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    stops: [0.0, 0.5, 1.0],
                                    colors: [Color(0x00000000), Color(0x99000000), Color(0xFF000000)],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (d) => _onTapUp(d, constraints.maxWidth),
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
                                          color: i == _index ? Colors.white : const Color(0x66FFFFFF),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),

                          // اسم + بلوکِ اطلاعات روی گرادینت — با باز شدنِ شیت محو می‌شن.
                          Positioned(
                            left: 20,
                            right: 16,
                            bottom: 18,
                            child: IgnorePointer(
                              ignoring: _expanded,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 220),
                                opacity: _expanded ? 0 : 1,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: IgnorePointer(
                                            child: Text('${widget.profile.name}  ${widget.profile.age}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _OpenProfileButton(expanded: _expanded, onTap: _toggleExpanded),
                                      ],
                                    ),
                                    if (block != null) ...[
                                      const SizedBox(height: 8),
                                      IgnorePointer(child: _buildBlock(block)),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // شیتِ اطلاعاتِ کامل — از پایین، روی عکس میاد بالا.
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            left: 0,
                            right: 0,
                            height: sheetHeight,
                            bottom: _expanded ? 0 : -sheetHeight,
                            child: _ProfileInfoSheet(
                              name: widget.profile.name,
                              age: widget.profile.age,
                              profile: widget.profile,
                              promptTextMap: widget.promptTextMap,
                              interestLabelMap: widget.interestLabelMap,
                              onCollapse: _toggleExpanded,
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
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

/// شیتِ اطلاعاتِ کامل که با زدنِ فلش، از پایینِ باکسِ عکس میاد بالا.
/// هدرش (اسم + فلشِ روبه‌پایین برای بستن) ثابته؛ بدنه اسکرول می‌خوره.
class _ProfileInfoSheet extends StatelessWidget {
  final String name;
  final int age;
  final MyProfile profile;
  final Map<String, String> promptTextMap;
  final Map<String, String> interestLabelMap;
  final VoidCallback onCollapse;

  const _ProfileInfoSheet({
    required this.name,
    required this.age,
    required this.profile,
    required this.promptTextMap,
    required this.interestLabelMap,
    required this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppDark.cardAlt,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text('$name، $age',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                ),
                _CollapseButton(onTap: onCollapse),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              child: MyProfileDetailSheet(
                profile: profile,
                promptTextMap: promptTextMap,
                interestLabelMap: interestLabelMap,
              ),
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

/// دکمه‌ی فلشِ روی عکس — دایره‌ی نیمه‌شفاف، عیناً کارت‌های سواپ؛ با تپ،
/// خودش ۱۸۰ درجه می‌چرخه (رو به پایین) و همزمان کل گروه (خودش هم) محو
/// می‌شه، چون کنترلِ باز/بسته‌شدن از این به بعد دستِ دکمه‌ی داخل شیته.
class _OpenProfileButton extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;
  const _OpenProfileButton({required this.expanded, required this.onTap});

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
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          turns: expanded ? 0.5 : 0,
          child: const Icon(Icons.arrow_upward, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

/// دکمه‌ی بستنِ شیت — دایره‌ی سفیدِ توپر با فلشِ رو‌به‌پایینِ مشکی.
class _CollapseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CollapseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: const CircleAvatar(
        radius: 16,
        backgroundColor: Colors.white,
        child: Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.black),
      ),
    );
  }
}
