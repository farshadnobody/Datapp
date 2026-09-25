// داده‌ی دسته‌های صفحه‌ی «اکسپلور» — دقیقاً شبیهِ بخشِ Explore تیندر: یه
// گریدِ تخت و یک‌دست از تایل‌های خاکستریِ تیره، هرکدوم با یه ایموجیِ
// گرافیکیِ بزرگ، عنوان و تعدادِ نمایشی — دقیقاً همون چیدمانی که تیندر
// خودش داره (نه دو بخشِ جدا با گرادیانت).
//
// چون بک‌اند فیلترِ سمتِ سرور برای این دسته‌ها نداره، فیلتر سمتِ کلاینت انجام
// می‌شه: کاندیدهای معمولیِ /api/discovery گرفته می‌شن و با متدِ [matches] این
// کلاس فیلتر می‌شن (نگاه کن به explore_category_screen.dart).
//
// عددهایی که کنارِ هر عنوان می‌بینی («count») فقط برای همون حسِ بصریِ
// تیندره (اونم اینجا واقعی نیست، یه تخمینِ سمتِ سرور از تعدادِ پروفایل‌هاست)؛
// اینجا چون همچین آماری از بک‌اند نمی‌گیریم، عددها ثابتن و صرفاً ظاهری‌ان.

import 'package:flutter/material.dart';
import '../models/profile_models.dart';

enum ExploreKind { intent, interest, lifestyle, wantChildren, verified }

class ExploreCategory {
  final String id;
  final String title;
  final String emoji; // گرافیکِ بزرگِ روی تایل (شبیهِ ایموجی‌های سه‌بعدیِ تیندر)
  final IconData icon; // آیکونِ کوچیک تو هدرِ صفحه‌ی دسته و حالتِ خالی
  final List<Color> gradient; // فقط برای همون دایره‌ی کوچیکِ هدر
  final int count; // عددِ نمایشیِ کنارِ عنوان
  final ExploreKind kind;

  /// برای kind == interest: زیرمجموعه‌ی تگ‌های این دسته (c.interests باید
  /// حداقل با یکیشون اشتراک داشته باشه).
  /// برای kind == intent: یه یا چندتا شناسه‌ی kLookingForOptions.
  /// برای kind == lifestyle: مقادیرِ قابلِ‌قبولِ همون فیلدِ lifestyle.
  /// برای kind == wantChildren: مقادیرِ قابلِ‌قبولِ kWantChildrenOptions.
  /// برای kind == verified: استفاده نمی‌شه.
  final Set<String> values;

  /// فقط برای kind == lifestyle: کلیدِ نقشه‌ی c.lifestyle (مثلاً 'pets').
  final String? lifestyleKey;

  const ExploreCategory({
    required this.id,
    required this.title,
    required this.emoji,
    required this.icon,
    required this.gradient,
    required this.count,
    required this.kind,
    this.values = const {},
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
      case ExploreKind.wantChildren:
        return c.wantChildren != null && values.contains(c.wantChildren);
      case ExploreKind.verified:
        return c.verified;
    }
  }
}

/// «دسته‌های اکسپلور» — یه گریدِ تخت و پیوسته، دقیقاً به همون ترتیبی که تویِ
/// اسکرین‌شات‌های Explore تیندر دیده می‌شه.
final List<ExploreCategory> kExploreCategories = [
  const ExploreCategory(
    id: 'gamers',
    title: 'گیمرها',
    emoji: '🎮',
    icon: Icons.sports_esports_outlined,
    gradient: [Color(0xFF9C4DCC), Color(0xFF5E3B9C)],
    count: 15,
    kind: ExploreKind.interest,
    values: {'gaming'},
  ),
  const ExploreCategory(
    id: 'foodies',
    title: 'شکموها',
    emoji: '🍑',
    icon: Icons.restaurant_outlined,
    gradient: [Color(0xFFFFC629), Color(0xFFCC8A00)],
    count: 37,
    kind: ExploreKind.interest,
    values: {'foodie'},
  ),
  const ExploreCategory(
    id: 'self_care',
    title: 'خودمراقبتی',
    emoji: '🦆',
    icon: Icons.spa_outlined,
    gradient: [Color(0xFF9AB9EA), Color(0xFF3D5C8A)],
    count: 61,
    kind: ExploreKind.interest,
    values: {'self_care'},
  ),
  const ExploreCategory(
    id: 'long_term',
    title: 'رابطه بلندمدت',
    emoji: '🌷',
    icon: Icons.favorite,
    gradient: [Color(0xFFE9190C), Color(0xFFFF6B6B)],
    count: 94,
    kind: ExploreKind.intent,
    values: {'long_term'},
  ),
  const ExploreCategory(
    id: 'serious_commitment',
    title: 'تعهدِ جدی',
    emoji: '💍',
    icon: Icons.favorite,
    gradient: [Color(0xFFCE130A), Color(0xFFF4907F)],
    count: 32,
    kind: ExploreKind.intent,
    values: {'long_term_open_short'},
  ),
  const ExploreCategory(
    id: 'short_term_fun',
    title: 'رابطه‌ی کوتاه و بی‌دغدغه',
    emoji: '🍭',
    icon: Icons.bolt,
    gradient: [Color(0xFF9AB9EA), Color(0xFF3D9CF0)],
    count: 57,
    kind: ExploreKind.intent,
    values: {'short_term_fun'},
  ),
  const ExploreCategory(
    id: 'new_friends',
    title: 'دنبال دوست جدید',
    emoji: '👋',
    icon: Icons.people_alt_outlined,
    gradient: [Color(0xFF3AA25C), Color(0xFF8CE0A6)],
    count: 63,
    kind: ExploreKind.intent,
    values: {'new_friends'},
  ),
  const ExploreCategory(
    id: 'get_photo_verified',
    title: 'تأیید عکس',
    emoji: '✅',
    icon: Icons.verified_outlined,
    gradient: [Color(0xFF3D9CF0), Color(0xFF1E5FA8)],
    count: 37,
    kind: ExploreKind.verified,
  ),
  const ExploreCategory(
    id: 'wants_kids',
    title: 'عاشق بچه',
    emoji: '🧸',
    icon: Icons.child_care_outlined,
    gradient: [Color(0xFFE9190C), Color(0xFFFF6B6B)],
    count: 3,
    kind: ExploreKind.wantChildren,
    values: {'want_children', 'have_and_want_more'},
  ),
  const ExploreCategory(
    id: 'travel',
    title: 'اهل سفر و گردش',
    emoji: '✈️',
    icon: Icons.flight_outlined,
    gradient: [Color(0xFFF4B0EC), Color(0xFFB57BE0)],
    count: 48,
    kind: ExploreKind.interest,
    values: {'travel', 'road_trips'},
  ),
  const ExploreCategory(
    id: 'binge_watchers',
    title: 'فیلم‌باز',
    emoji: '📺',
    icon: Icons.tv_outlined,
    gradient: [Color(0xFFF4B0EC), Color(0xFFB57BE0)],
    count: 27,
    kind: ExploreKind.interest,
    values: {'binge_watching'},
  ),
  const ExploreCategory(
    id: 'sporty',
    title: 'اهل تحرک و ورزش',
    emoji: '🥤',
    icon: Icons.fitness_center,
    gradient: [Color(0xFFE9190C), Color(0xFF8C0C05)],
    count: 31,
    kind: ExploreKind.interest,
    values: {
      'gym', 'running', 'football', 'swimming', 'yoga',
      'climbing', 'cycling', 'martial_arts',
    },
  ),
  const ExploreCategory(
    id: 'coffee_date',
    title: 'گپ با قهوه',
    emoji: '☕',
    icon: Icons.local_cafe_outlined,
    gradient: [Color(0xFFB08968), Color(0xFF6F4E37)],
    count: 52,
    kind: ExploreKind.interest,
    values: {'coffee'},
  ),
  const ExploreCategory(
    id: 'date_night',
    title: 'اهل بیرون رفتن',
    emoji: '🍷',
    icon: Icons.wine_bar_outlined,
    gradient: [Color(0xFF9C4DCC), Color(0xFF5E3B9C)],
    count: 21,
    kind: ExploreKind.interest,
    values: {'cafe_hopping', 'cinema', 'live_music', 'theater'},
  ),
  const ExploreCategory(
    id: 'thrill_seekers',
    title: 'دنبال ماجراجویی',
    emoji: '🎢',
    icon: Icons.rocket_launch_outlined,
    gradient: [Color(0xFFF4A11F), Color(0xFFFFD36B)],
    count: 23,
    kind: ExploreKind.interest,
    values: {'climbing', 'hiking', 'cycling', 'road_trips'},
  ),
  const ExploreCategory(
    id: 'creatives',
    title: 'خلاق‌ها',
    emoji: '📌',
    icon: Icons.palette_outlined,
    gradient: [Color(0xFFF4B0EC), Color(0xFFB57BE0)],
    count: 63,
    kind: ExploreKind.interest,
    values: {
      'photography', 'painting', 'writing', 'dancing',
      'singing', 'handicraft', 'poetry', 'design',
    },
  ),
  const ExploreCategory(
    id: 'nature_lovers',
    title: 'دوستدارِ طبیعت',
    emoji: '🌱',
    icon: Icons.eco_outlined,
    gradient: [Color(0xFF3AA25C), Color(0xFF1F5C33)],
    count: 42,
    kind: ExploreKind.interest,
    values: {'hiking', 'camping', 'beach', 'nature'},
  ),
  const ExploreCategory(
    id: 'animal_parents',
    title: 'حیوان‌دوست‌ها',
    emoji: '🐾',
    icon: Icons.pets,
    gradient: [Color(0xFFB08968), Color(0xFF6F4E37)],
    count: 4,
    kind: ExploreKind.lifestyle,
    lifestyleKey: 'pets',
    values: {
      'dog', 'cat', 'reptile', 'amphibian', 'bird', 'fish',
      'turtle', 'hamster', 'rabbit', 'all_the_pets',
    },
  ),
];
