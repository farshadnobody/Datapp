import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../models/profile_models.dart';
import '../onboarding/onboarding_data.dart';
import 'swipe_style.dart';

/// کارت پروفایل سبک تیندر.
///
/// - تپ روی نیمه‌ی راست/چپ کارت → عکس بعدی/قبلی (با نقطه‌های بالای کارت).
/// - پایین کارت همیشه اسم و سن هست؛ زیرش یه «بلوک اطلاعات» که با عوض شدن
///   عکس عوض می‌شه (بیو ← دنبال چی می‌گرده ← علاقه‌مندی‌ها ← مشخصات و سبک
///   زندگی)، فقط بلوک‌هایی که داده‌شون هست.
/// - دکمه‌ی فلش کنار اسم → صفحه‌ی جزئیات.
class SwipeProfileCard extends StatefulWidget {
  final DiscoveryCandidate candidate;

  /// id → برچسب علاقه‌مندی‌ها (از /api/profile/options).
  final Map<String, String> interestLabels;

  /// علاقه‌مندی‌های خود کاربر؛ مشترک‌ها صورتی نشون داده می‌شن.
  final Set<String> myInterests;

  final VoidCallback onOpenProfile;

  const SwipeProfileCard({
    super.key,
    required this.candidate,
    required this.onOpenProfile,
    this.interestLabels = const {},
    this.myInterests = const {},
  });

  @override
  State<SwipeProfileCard> createState() => _SwipeProfileCardState();
}

enum _Block { bio, lookingFor, interests, basics }

class _SwipeProfileCardState extends State<SwipeProfileCard> {
  int _index = 0;

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
    final goNext = d.localPosition.dx >= width / 2;
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
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(SwipeMetrics.cardRadius),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
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
              // گرادیانت پایین — تا رنگ ته کارت (زیر دکمه‌ها) ادامه داره
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: constraints.maxHeight * 0.6,
                child: const IgnorePointer(
                  child: DecoratedBox(
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
      }),
    );
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
          IgnorePointer(child: _StatusPill(status: c.activityStatus!)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: IgnorePointer(
                child: Text.rich(
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    height: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _OpenProfileButton(onTap: widget.onOpenProfile),
          ],
        ),
        if (block != null) ...[
          const SizedBox(height: 8),
          IgnorePointer(child: _buildBlock(block)),
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

class _OpenProfileButton extends StatelessWidget {
  final VoidCallback onTap;
  const _OpenProfileButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Color(0x33FFFFFF),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_upward, size: 18, color: Colors.white),
      ),
    );
  }
}
