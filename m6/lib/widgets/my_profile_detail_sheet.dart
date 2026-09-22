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

IconData _aboutYouIcon(String category) {
  switch (category) {
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

/// پنلی که با زدن فلش کنار اسم تو Preview Profile از پایین کارت باز می‌شه
/// و با کشیدن به پایین، اسکرول می‌شه (عکس‌های ۴ تا ۶).
class MyProfileDetailSheet extends StatelessWidget {
  final MyProfile profile;
  final Map<String, String> promptTextMap;
  final Map<String, String> interestLabelMap;
  final ScrollController scrollController;

  const MyProfileDetailSheet({
    super.key,
    required this.profile,
    required this.promptTextMap,
    required this.interestLabelMap,
    required this.scrollController,
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
    final essentials = <Widget>[];
    if ((p.cityName ?? '').isNotEmpty && p.showCityOnProfile) {
      essentials.add(_kvRow(Icons.location_on_outlined, p.cityName!));
    }
    if (p.genders.isNotEmpty && p.showGenderOnProfile) {
      essentials.add(_kvRow(Icons.person_outline, optionLabel(kGenderOptions, p.genders.first) ?? p.genders.first));
    }

    final basics = <(IconData, String, String)>[];
    final loveLanguage = optionLabel(
        kAboutYouCategories.firstWhere((c) => c.id == 'love_language').items, p.aboutYou['love_language']);
    if (loveLanguage != null) basics.add((Icons.favorite_border, 'سبک عشق‌ورزی', loveLanguage));
    final education = optionLabel(kEducationOptions, p.educationLevel);
    if (education != null) basics.add((Icons.school_outlined, 'تحصیلات', education));
    final communication = optionLabel(
        kAboutYouCategories.firstWhere((c) => c.id == 'communication').items, p.aboutYou['communication']);
    if (communication != null) basics.add((Icons.chat_bubble_outline, 'سبک ارتباطی', communication));
    final zodiac =
        optionLabel(kAboutYouCategories.firstWhere((c) => c.id == 'zodiac').items, p.aboutYou['zodiac']);
    if (zodiac != null) basics.add((Icons.nightlight_outlined, 'برج', zodiac));

    final lifestyleOrder = ['drinking', 'smoking', 'workout', 'pets', 'social_media'];
    final lifestyleChips = <Widget>[];
    for (final id in lifestyleOrder) {
      final cat = kLifestyleCategories.where((c) => c.id == id);
      if (cat.isEmpty) continue;
      final value = p.lifestyle[id];
      final label = optionLabel(cat.first.items, value);
      if (label == null) continue;
      lifestyleChips.add(_chip(_lifestyleIcon(id, value!), label));
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: AppDark.border, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        if (p.lookingFor != null) ...[
          _sectionHeader(Icons.search, 'دنبال چی می‌گردی'),
          const SizedBox(height: 10),
          Text(optionLabel(kLookingForOptions, p.lookingFor) ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),
        ],
        if (p.bio.trim().isNotEmpty) ...[
          _sectionHeader(Icons.format_quote, 'درباره‌ی من'),
          const SizedBox(height: 10),
          Text(p.bio.trim(), style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5)),
          const SizedBox(height: 24),
        ],
        if (essentials.isNotEmpty) ...[
          _sectionHeader(Icons.badge_outlined, 'اطلاعات پایه'),
          const SizedBox(height: 10),
          ...essentials,
          const SizedBox(height: 24),
        ],
        for (final prompt in p.prompts) ...[
          _sectionHeader(Icons.format_quote, promptTextMap[prompt.promptId] ?? ''),
          const SizedBox(height: 10),
          Text(prompt.answer, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
        ],
        if (basics.isNotEmpty) ...[
          _sectionHeader(Icons.label_outline, 'Basics'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: basics.map((b) => _chip(b.$1, b.$3)).toList(),
          ),
          const SizedBox(height: 24),
        ],
        if (lifestyleChips.isNotEmpty) ...[
          _sectionHeader(Icons.label_outline, 'Lifestyle'),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: lifestyleChips),
          const SizedBox(height: 24),
        ],
        if (p.interests.isNotEmpty) ...[
          _sectionHeader(Icons.interests, 'علاقه‌مندی‌ها'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: p.interests.map((id) => _chip(null, _interestLabel(id))).toList(),
          ),
        ],
      ],
    );
  }

  Widget _sectionHeader(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppDark.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(color: AppDark.muted, fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _kvRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppDark.muted),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _chip(IconData? icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: icon == null ? 14 : 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDark.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}
