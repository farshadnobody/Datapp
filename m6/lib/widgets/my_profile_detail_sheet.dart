import 'package:flutter/material.dart';
import '../models/profile_models.dart';
import '../onboarding/onboarding_data.dart';
import '../style/app_colors.dart';

IconData _lifestyleIcon(String category, String value) {
  switch (category) {
    case 'drinking':
      return Icons.wine_bar_outlined;
    case 'smoking':
      return value == 'non_smoker' ? Icons.smoke_free : Icons.smoking_rooms;
    case 'workout':
      return Icons.fitness_center;
    case 'pets':
      return Icons.pets;
    case 'social_media':
      return Icons.alternate_email;
    default:
      return Icons.circle_outlined;
  }
}

/// اطلاعاتی که زیر عکس پروفایل تو Preview باز می‌شه — هر بخش تو باکس
/// گردگوشه‌ی خودش، دقیقاً مثل تیندر: باکس‌های تک‌سؤالی (Looking for /
/// About Me / هر پرامپت) با یه لیبل خاکستری کوچیک بالا و جواب بولد
/// پایینش، و باکس‌های گروهی (اطلاعات پایه / Basics / Lifestyle) با یه
/// تیتر سفید بولد بالا و چندتا ردیف لیبل:مقدار زیرش که با خط نازک از هم
/// جدا می‌شن.
class MyProfileDetailSheet extends StatelessWidget {
  final MyProfile profile;
  final Map<String, String> promptTextMap;
  final Map<String, String> interestLabelMap;

  const MyProfileDetailSheet({
    super.key,
    required this.profile,
    required this.promptTextMap,
    required this.interestLabelMap,
  });

  String _interestLabel(String id) {
    final fromApi = interestLabelMap[id];
    if (fromApi != null) return fromApi;
    for (final cat in kInterestCategories) {
      final l = optionLabel(cat.items, id);
      if (l != null) return l;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;

    final essentialsRows = <(IconData, String, String)>[];
    if ((p.cityName ?? '').isNotEmpty && p.showCityOnProfile) {
      essentialsRows.add((Icons.location_on_outlined, 'شهر', p.cityName!));
    }
    if (p.genders.isNotEmpty && p.showGenderOnProfile) {
      essentialsRows
          .add((Icons.person_outline, 'جنسیت', optionLabel(kGenderOptions, p.genders.first) ?? p.genders.first));
    }

    final basicsRows = <(IconData, String, String)>[];
    final loveLanguage = optionLabel(
        kAboutYouCategories.firstWhere((c) => c.id == 'love_language').items, p.aboutYou['love_language']);
    if (loveLanguage != null) basicsRows.add((Icons.favorite_border, 'سبک عشق‌ورزی', loveLanguage));
    final education = optionLabel(kEducationOptions, p.educationLevel);
    if (education != null) basicsRows.add((Icons.school_outlined, 'تحصیلات', education));
    final communication = optionLabel(
        kAboutYouCategories.firstWhere((c) => c.id == 'communication').items, p.aboutYou['communication']);
    if (communication != null) basicsRows.add((Icons.chat_bubble_outline, 'سبک ارتباطی', communication));
    final zodiac =
        optionLabel(kAboutYouCategories.firstWhere((c) => c.id == 'zodiac').items, p.aboutYou['zodiac']);
    if (zodiac != null) basicsRows.add((Icons.nightlight_outlined, 'برج', zodiac));
    final wantChildren = optionLabel(kWantChildrenOptions, p.wantChildren);
    if (wantChildren != null) basicsRows.add((Icons.child_care_outlined, 'بچه', wantChildren));

    final lifestyleOrder = ['drinking', 'smoking', 'workout', 'pets', 'social_media'];
    final lifestyleRows = <(IconData, String, String)>[];
    for (final id in lifestyleOrder) {
      final cat = kLifestyleCategories.where((c) => c.id == id);
      if (cat.isEmpty) continue;
      final value = p.lifestyle[id];
      final label = optionLabel(cat.first.items, value);
      if (label == null) continue;
      lifestyleRows.add((_lifestyleIcon(id, value!), cat.first.title, label));
    }

    final boxes = <Widget>[
      if (p.lookingFor != null)
        _qaBox(Icons.search, 'دنبال چی می‌گردی', optionLabel(kLookingForOptions, p.lookingFor) ?? ''),
      if (p.bio.trim().isNotEmpty) _qaBox(Icons.format_quote, 'درباره‌ی من', p.bio.trim()),
      if (essentialsRows.isNotEmpty) _groupBox('اطلاعات پایه', Icons.badge_outlined, essentialsRows),
      for (final prompt in p.prompts)
        if (prompt.answer.trim().isNotEmpty)
          _qaBox(Icons.format_quote, promptTextMap[prompt.promptId] ?? '', prompt.answer),
      if (basicsRows.isNotEmpty) _groupBox('Basics', Icons.label_outline, basicsRows),
      if (lifestyleRows.isNotEmpty) _groupBox('Lifestyle', Icons.label_outline, lifestyleRows),
      if (p.interests.isNotEmpty)
        _chipsBox('علاقه‌مندی‌ها', Icons.interests, p.interests.map(_interestLabel).toList()),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final box in boxes) Padding(padding: const EdgeInsets.only(bottom: 12), child: box),
      ],
    );
  }

  Widget _box({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppDark.card, borderRadius: BorderRadius.circular(16)),
      child: child,
    );
  }

  /// باکس تک‌سؤالی: لیبل خاکستری کوچیک + آیکون بالا، جواب بولد پایین.
  Widget _qaBox(IconData icon, String label, String value) {
    return _box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: AppDark.muted),
            const SizedBox(width: 8),
            Expanded(
              child:
                  Text(label, style: const TextStyle(color: AppDark.muted, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 10),
          Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700, height: 1.4)),
        ],
      ),
    );
  }

  /// باکس گروهی: تیتر سفید بولد بالا (اطلاعات پایه / Basics / Lifestyle)،
  /// بعد چندتا ردیف آیکون+لیبل+مقدار که با خط نازک از هم جدا می‌شن.
  Widget _groupBox(String title, IconData titleIcon, List<(IconData, String, String)> rows) {
    return _box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(titleIcon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10), child: Divider(color: AppDark.border, height: 1)),
            Row(children: [
              Icon(rows[i].$1, size: 16, color: AppDark.muted),
              const SizedBox(width: 10),
              Text(rows[i].$2, style: const TextStyle(color: AppDark.muted, fontSize: 13)),
              const Spacer(),
              Text(rows[i].$3, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _chipsBox(String title, IconData titleIcon, List<String> items) {
    return _box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(titleIcon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map((label) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppDark.border),
                      ),
                      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
