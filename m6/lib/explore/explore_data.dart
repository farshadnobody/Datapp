// داده‌ی دسته‌های صفحه‌ی «اکسپلور» — دقیقاً شبیهِ بخشِ Explore تیندر:
//
// - «My Vibe» تیندر → این‌جا «دسته‌های نیتِ رابطه»: هر تایل یکی از گزینه‌های
//   «دنبال چه نوع رابطه‌ای هستی» (kLookingForOptions) رو نمایندگی می‌کنه.
//   کاندیدی که c.lookingFor باهاش یکی باشه تویِ اون تایل قرار می‌گیره —
//   دقیقاً مثلِ تیندر که هر کاربر با یه نیتِ مشخص عضوِ یه گروه می‌شه.
// - «Passions» تیندر → این‌جا «دسته‌های علاقه و سبکِ زندگی»: بیشترش از رو
//   دسته‌های اونبوردینگِ علایق (kInterestCategories) ساخته شده (هر دسته یه
//   تایل، شاملِ همه‌ی زیرتگ‌هاش)، به‌علاوه‌ی دو تایلِ سبکِ زندگی‌ که تیندر هم
//   به‌عنوانِ Passion داره: صاحبِ حیوانِ خونگی و اهلِ باشگاه.
//
// چون بک‌اند فیلترِ سمتِ سرور برای این دسته‌ها نداره، فیلتر سمتِ کلاینت انجام
// می‌شه: کاندیدهای معمولیِ /api/discovery گرفته می‌شن و با متدِ [matches] این
// کلاس فیلتر می‌شن (نگاه کن به explore_category_screen.dart).

import 'package:flutter/material.dart';
import '../models/profile_models.dart';
import '../onboarding/onboarding_data.dart';

enum ExploreKind { intent, interest, lifestyle }

class ExploreCategory {
  final String id;
  final String title;
  final IconData icon;
  final List<Color> gradient;
  final ExploreKind kind;

  /// برای kind == interest: زیرمجموعه‌ی تگ‌های این دسته (c.interests باید
  /// حداقل با یکیشون اشتراک داشته باشه).
  /// برای kind == intent: دقیقاً یه شناسه‌ی kLookingForOptions.
  /// برای kind == lifestyle: مقادیرِ قابلِ‌قبولِ همون فیلدِ lifestyle.
  final Set<String> values;

  /// فقط برای kind == lifestyle: کلیدِ نقشه‌ی c.lifestyle (مثلاً 'pets').
  final String? lifestyleKey;

  const ExploreCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.gradient,
    required this.kind,
    required this.values,
    this.lifestyleKey,
  });

  bool matches(DiscoveryCandidate c) {
    switch (kind) {
      case ExploreKind.intent:
        return c.lookingFor != null && values.contains(c.lookingFor);
      case ExploreKind.interest:
        return c.interests.any(values.contains);
      case ExploreKind.lifestyle:
        final v = c.lifestyle[lifestyleKey];
        return v != null && values.contains(v);
    }
  }
}

IconData _intentIcon(String id) {
  switch (id) {
    case 'long_term':
      return Icons.favorite;
    case 'long_term_open_short':
      return Icons.favorite_border;
    case 'short_term_open_long':
      return Icons.local_fire_department_outlined;
    case 'short_term_fun':
      return Icons.bolt;
    case 'new_friends':
      return Icons.people_alt_outlined;
    case 'figuring_out':
      return Icons.help_outline;
    default:
      return Icons.favorite_border;
  }
}

List<Color> _intentGradient(String id) {
  switch (id) {
    case 'long_term':
      return const [Color(0xFFE9190C), Color(0xFFFF6B6B)];
    case 'long_term_open_short':
      return const [Color(0xFFCE130A), Color(0xFFF4907F)];
    case 'short_term_open_long':
      return const [Color(0xFFF4A11F), Color(0xFFFFD36B)];
    case 'short_term_fun':
      return const [Color(0xFF9AB9EA), Color(0xFF3D9CF0)];
    case 'new_friends':
      return const [Color(0xFF3AA25C), Color(0xFF8CE0A6)];
    case 'figuring_out':
      return const [Color(0xFF6E6E72), Color(0xFFAEAEB2)];
    default:
      return const [Color(0xFF6E6E72), Color(0xFFAEAEB2)];
  }
}

/// «دسته‌های نیتِ رابطه» — از رویِ kLookingForOptions، همون فیلدی که تویِ
/// اونبوردینگ/پروفایل هست؛ برای همین چیزِ جدیدی از کاربر پرسیده نمی‌شه.
final List<ExploreCategory> kIntentCategories = kLookingForOptions
    .map((o) => ExploreCategory(
          id: o.id,
          title: o.label,
          icon: _intentIcon(o.id),
          gradient: _intentGradient(o.id),
          kind: ExploreKind.intent,
          values: {o.id},
        ))
    .toList(growable: false);

IconData _interestCategoryIcon(String id) {
  switch (id) {
    case 'creativity':
      return Icons.palette_outlined;
    case 'going_out':
      return Icons.local_bar_outlined;
    case 'staying_in':
      return Icons.home_outlined;
    case 'sports_fitness':
      return Icons.fitness_center;
    case 'outdoors':
      return Icons.terrain_outlined;
    case 'music':
      return Icons.music_note_outlined;
    case 'food_drink':
      return Icons.restaurant_outlined;
    case 'values':
      return Icons.volunteer_activism_outlined;
    case 'wellness':
      return Icons.spa_outlined;
    default:
      return Icons.interests_outlined;
  }
}

List<Color> _interestCategoryGradient(String id) {
  switch (id) {
    case 'creativity':
      return const [Color(0xFFF4B0EC), Color(0xFFB57BE0)];
    case 'going_out':
      return const [Color(0xFF9C4DCC), Color(0xFF5E3B9C)];
    case 'staying_in':
      return const [Color(0xFF3D9CF0), Color(0xFF1E5FA8)];
    case 'sports_fitness':
      return const [Color(0xFFE9190C), Color(0xFF8C0C05)];
    case 'outdoors':
      return const [Color(0xFF3AA25C), Color(0xFF1F5C33)];
    case 'music':
      return const [Color(0xFFF4A11F), Color(0xFFB56E0A)];
    case 'food_drink':
      return const [Color(0xFFFFC629), Color(0xFFCC8A00)];
    case 'values':
      return const [Color(0xFF6BC6C1), Color(0xFF2E7D78)];
    case 'wellness':
      return const [Color(0xFF9AB9EA), Color(0xFF3D5C8A)];
    default:
      return const [Color(0xFF6E6E72), Color(0xFF3A3A3D)];
  }
}

/// «دسته‌های علاقه و سبکِ زندگی»:
/// - یه تایل به‌ازایِ هر دسته‌ی kInterestCategories (تیندر هم اکثرِ Passion‌
///   هاش رو از رویِ همین‌جور دسته‌های علاقه می‌سازه).
/// - + دو تایلِ سبکِ زندگیِ شبیهِ Passion‌های واقعیِ تیندر («Pet Parents» و
///   اهلِ باشگاه)، از رویِ kLifestyleCategories.
final List<ExploreCategory> kInterestLifestyleCategories = [
  for (final cat in kInterestCategories)
    ExploreCategory(
      id: 'interest_${cat.id}',
      title: cat.title,
      icon: _interestCategoryIcon(cat.id),
      gradient: _interestCategoryGradient(cat.id),
      kind: ExploreKind.interest,
      values: cat.items.map((i) => i.id).toSet(),
    ),
  const ExploreCategory(
    id: 'lifestyle_pets',
    title: 'صاحبِ حیوونِ خونگی',
    icon: Icons.pets,
    gradient: [Color(0xFFB08968), Color(0xFF6F4E37)],
    kind: ExploreKind.lifestyle,
    lifestyleKey: 'pets',
    values: {
      'dog', 'cat', 'reptile', 'amphibian', 'bird', 'fish',
      'turtle', 'hamster', 'rabbit', 'all_the_pets',
    },
  ),
  const ExploreCategory(
    id: 'lifestyle_gym',
    title: 'اهلِ باشگاه',
    icon: Icons.sports_gymnastics_outlined,
    gradient: [Color(0xFF3AA25C), Color(0xFF1F5C33)],
    kind: ExploreKind.lifestyle,
    lifestyleKey: 'workout',
    values: {'everyday', 'often'},
  ),
];
