// داده‌ی دسته‌های صفحه‌ی «اکسپلور» — دقیقاً شبیهِ بخشِ Explore تیندر: یه
// گریدِ تخت و یک‌دست از تایل‌های خاکستریِ تیره، هرکدوم با یه ایموجیِ
// گرافیکیِ بزرگ، عنوان و تعدادِ نمایشی — دقیقاً همون چیدمانی که تیندر
// خودش داره (نه دو بخشِ جدا با گرادیانت).
//
// فیلترِ دسته‌ها کاملاً سمتِ سرور انجام می‌شه: [ExploreCategory.id] به‌عنوانِ
// `explore_id` به GET /api/discovery فرستاده می‌شه و بک‌اند (store/explore.go) همین
// IDها رو به شرطِ SQL تبدیل می‌کنه. هیچ فیلترِ سمتِ کلاینتی وجود نداره؛ [kind] و
// [values] فقط توصیفِ دسته‌ان و منبعِ حقیقتِ IDها این فایله.
//
// تعدادِ آدم‌ها دیگه هیچ‌جا نشون داده نمی‌شه. لیستِ «نمایشی‌ها»، عنوان، ایموجی و ترتیبِ
// دسته‌ها از پنلِ ادمین میاد (bootstrap، کلیدِ `explore`) و روی گوشی ذخیره می‌شه؛ فقط
// وقتی نسخه‌اش عوض شده باشه دوباره گرفته می‌شه. تا وقتی چیزی نرسیده، همین لیستِ پیش‌فرضِ
// داخلِ اپ ([kDefaultExploreCategories]) نشون داده می‌شه.

import 'package:flutter/material.dart';

enum ExploreKind { intent, interest, lifestyle, wantChildren }

class ExploreCategory {
  final String id;
  final String title;
  final String emoji; // ایموجیِ یونیکدِ ساده — فقط به‌عنوانِ فال‌بک، تا وقتی عکسِ سه‌بعدی بارگذاری نشده
  final String imageAsset; // مسیرِ فایلِ گرافیکِ سه‌بعدی (assets/explore_icons/<id>.png)
  final IconData icon; // آیکونِ کوچیک تو هدرِ صفحه‌ی دسته و حالتِ خالی
  final List<Color> gradient; // فقط برای همون دایره‌ی کوچیکِ هدر
  final ExploreKind kind;

  /// برای kind == interest: زیرمجموعه‌ی تگ‌های این دسته (c.interests باید
  /// حداقل با یکیشون اشتراک داشته باشه).
  /// برای kind == intent: یه یا چندتا شناسه‌ی kLookingForOptions.
  /// برای kind == lifestyle: مقادیرِ قابلِ‌قبولِ همون فیلدِ lifestyle.
  /// برای kind == wantChildren: مقادیرِ قابلِ‌قبولِ kWantChildrenOptions.
  final Set<String> values;

  /// فقط برای kind == lifestyle: کلیدِ نقشه‌ی c.lifestyle (مثلاً 'pets').
  final String? lifestyleKey;

  const ExploreCategory({
    required this.id,
    required this.title,
    required this.emoji,
    required this.imageAsset,
    required this.icon,
    required this.gradient,
    required this.kind,
    this.values = const {},
    this.lifestyleKey,
  });

  /// فقط عنوان و ایموجی از سرور عوض می‌شن؛ بقیه (تصویر، آیکون، گرادیان) همون پیش‌فرضِ اپ.
  ExploreCategory copyWith({String? title, String? emoji}) => ExploreCategory(
        id: id,
        title: title ?? this.title,
        emoji: emoji ?? this.emoji,
        imageAsset: imageAsset,
        icon: icon,
        gradient: gradient,
        kind: kind,
        values: values,
        lifestyleKey: lifestyleKey,
      );
}

/// لیستِ دسته‌های اکسپلور که الان باید نشون داده بشه. از bootstrap (کلیدِ `explore`) پر می‌شه.
/// دسته‌ی جدیدی که ادمین ساخته و تو اپ تصویرِ سه‌بعدی نداره با ایموجی نشون داده می‌شه
/// (ExploreScreen برای نبودنِ فایلِ تصویر از قبل errorBuilder داره).
class ExploreConfig extends ChangeNotifier {
  ExploreConfig._();
  static final ExploreConfig instance = ExploreConfig._();

  List<ExploreCategory> _categories = kDefaultExploreCategories;
  List<ExploreCategory> get categories => _categories;

  /// [list] همون json['explore'] از bootstrapه: [{id, title, emoji}, ...] فقط دسته‌های
  /// نمایشی و به ترتیب. لیستِ خالی یعنی «همه مخفی‌ان».
  void apply(List<dynamic> list) {
    final byId = {for (final c in kDefaultExploreCategories) c.id: c};
    final out = <ExploreCategory>[];
    for (final e in list) {
      if (e is! Map) continue;
      final id = e['id'];
      if (id is! String || id.isEmpty) continue;
      final title = e['title'] is String && (e['title'] as String).isNotEmpty ? e['title'] as String : null;
      final emoji = e['emoji'] is String && (e['emoji'] as String).isNotEmpty ? e['emoji'] as String : null;
      final base = byId[id];
      if (base != null) {
        out.add(base.copyWith(title: title, emoji: emoji));
      } else {
        out.add(ExploreCategory(
          id: id,
          title: title ?? id,
          emoji: emoji ?? '✨',
          imageAsset: 'assets/explore_icons/$id.png',
          icon: Icons.explore_outlined,
          gradient: const [Color(0xFF6C63FF), Color(0xFF3F3D9E)],
          kind: ExploreKind.interest, // فقط توصیفیه؛ فیلتر سمتِ سروره
        ));
      }
    }
    _categories = out;
    notifyListeners();
  }
}

/// «دسته‌های اکسپلور» — یه گریدِ تخت و پیوسته، دقیقاً به همون ترتیبی که تویِ
/// اسکرین‌شات‌های Explore تیندر دیده می‌شه.
const List<ExploreCategory> kDefaultExploreCategories = [
  const ExploreCategory(
    id: 'gamers',
    title: 'گیمرها',
    emoji: '🎮',
    imageAsset: 'assets/explore_icons/gamers.png',
    icon: Icons.sports_esports_outlined,
    gradient: [Color(0xFF9C4DCC), Color(0xFF5E3B9C)],
    kind: ExploreKind.interest,
    values: {'gaming'},
  ),
  const ExploreCategory(
    id: 'foodies',
    title: 'شکموها',
    emoji: '🍑',
    imageAsset: 'assets/explore_icons/foodies.png',
    icon: Icons.restaurant_outlined,
    gradient: [Color(0xFFFFC629), Color(0xFFCC8A00)],
    kind: ExploreKind.interest,
    values: {'foodie'},
  ),
  const ExploreCategory(
    id: 'self_care',
    title: 'اهل خودمراقبتی',
    emoji: '🦆',
    imageAsset: 'assets/explore_icons/self_care.png',
    icon: Icons.spa_outlined,
    gradient: [Color(0xFF9AB9EA), Color(0xFF3D5C8A)],
    kind: ExploreKind.interest,
    values: {'self_care'},
  ),
  const ExploreCategory(
    id: 'long_term',
    title: 'رابطه بلندمدت',
    emoji: '🌷',
    imageAsset: 'assets/explore_icons/long_term.png',
    icon: Icons.favorite,
    gradient: [Color(0xFFE9190C), Color(0xFFFF6B6B)],
    kind: ExploreKind.intent,
    values: {'long_term'},
  ),
  const ExploreCategory(
    id: 'serious_commitment',
    title: 'تعهدِ جدی',
    emoji: '💍',
    imageAsset: 'assets/explore_icons/serious_commitment.png',
    icon: Icons.favorite,
    gradient: [Color(0xFFCE130A), Color(0xFFF4907F)],
    kind: ExploreKind.intent,
    values: {'long_term_open_short'},
  ),
  const ExploreCategory(
    id: 'short_term_fun',
    title: 'رابطه‌ی کوتاه و بی‌دغدغه',
    emoji: '🍭',
    imageAsset: 'assets/explore_icons/short_term_fun.png',
    icon: Icons.bolt,
    gradient: [Color(0xFF9AB9EA), Color(0xFF3D9CF0)],
    kind: ExploreKind.intent,
    values: {'short_term_fun'},
  ),
  const ExploreCategory(
    id: 'new_friends',
    title: 'دنبال دوست جدید',
    emoji: '👋',
    imageAsset: 'assets/explore_icons/new_friends.png',
    icon: Icons.people_alt_outlined,
    gradient: [Color(0xFF3AA25C), Color(0xFF8CE0A6)],
    kind: ExploreKind.intent,
    values: {'new_friends'},
  ),
  const ExploreCategory(
    id: 'wants_kids',
    title: 'خانواده‌دوست‌ها',
    emoji: '🧸',
    imageAsset: 'assets/explore_icons/wants_kids.png',
    icon: Icons.child_care_outlined,
    gradient: [Color(0xFFE9190C), Color(0xFFFF6B6B)],
    kind: ExploreKind.wantChildren,
    values: {'want_children', 'have_and_want_more'},
  ),
  const ExploreCategory(
    id: 'travel',
    title: 'اهل سفر و گردش',
    emoji: '✈️',
    imageAsset: 'assets/explore_icons/travel.png',
    icon: Icons.flight_outlined,
    gradient: [Color(0xFFF4B0EC), Color(0xFFB57BE0)],
    kind: ExploreKind.interest,
    values: {'travel', 'road_trips'},
  ),
  const ExploreCategory(
    id: 'binge_watchers',
    title: 'فیلم‌باز',
    emoji: '📺',
    imageAsset: 'assets/explore_icons/binge_watchers.png',
    icon: Icons.tv_outlined,
    gradient: [Color(0xFFF4B0EC), Color(0xFFB57BE0)],
    kind: ExploreKind.interest,
    values: {'binge_watching'},
  ),
  const ExploreCategory(
    id: 'sporty',
    title: 'اهل تحرک و ورزش',
    emoji: '🥤',
    imageAsset: 'assets/explore_icons/sporty.png',
    icon: Icons.fitness_center,
    gradient: [Color(0xFFE9190C), Color(0xFF8C0C05)],
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
    imageAsset: 'assets/explore_icons/coffee_date.png',
    icon: Icons.local_cafe_outlined,
    gradient: [Color(0xFFB08968), Color(0xFF6F4E37)],
    kind: ExploreKind.interest,
    values: {'coffee'},
  ),
  const ExploreCategory(
    id: 'date_night',
    title: 'اهل بیرون رفتن',
    emoji: '🍷',
    imageAsset: 'assets/explore_icons/date_night.png',
    icon: Icons.wine_bar_outlined,
    gradient: [Color(0xFF9C4DCC), Color(0xFF5E3B9C)],
    kind: ExploreKind.interest,
    values: {'cafe_hopping', 'cinema', 'live_music', 'theater'},
  ),
  const ExploreCategory(
    id: 'thrill_seekers',
    title: 'دنبال ماجراجویی',
    emoji: '🎢',
    imageAsset: 'assets/explore_icons/thrill_seekers.png',
    icon: Icons.rocket_launch_outlined,
    gradient: [Color(0xFFF4A11F), Color(0xFFFFD36B)],
    kind: ExploreKind.interest,
    values: {'climbing', 'hiking', 'cycling', 'road_trips'},
  ),
  const ExploreCategory(
    id: 'creatives',
    title: 'خلاق‌ها',
    emoji: '📌',
    imageAsset: 'assets/explore_icons/creatives.png',
    icon: Icons.palette_outlined,
    gradient: [Color(0xFFF4B0EC), Color(0xFFB57BE0)],
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
    imageAsset: 'assets/explore_icons/nature_lovers.png',
    icon: Icons.eco_outlined,
    gradient: [Color(0xFF3AA25C), Color(0xFF1F5C33)],
    kind: ExploreKind.interest,
    values: {'hiking', 'camping', 'beach', 'nature'},
  ),
  const ExploreCategory(
    id: 'animal_parents',
    title: 'عاشق حیوانات',
    emoji: '🐾',
    imageAsset: 'assets/explore_icons/animal_parents.png',
    icon: Icons.pets,
    gradient: [Color(0xFFB08968), Color(0xFF6F4E37)],
    kind: ExploreKind.lifestyle,
    lifestyleKey: 'pets',
    values: {
      'dog', 'cat', 'reptile', 'amphibian', 'bird', 'fish',
      'turtle', 'hamster', 'rabbit', 'all_the_pets',
    },
  ),
];
