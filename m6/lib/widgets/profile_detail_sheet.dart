import 'package:flutter/material.dart';
import '../api_client.dart';
import '../models/profile_models.dart';
import '../swipe/swipe_style.dart';

// نکته: onSwipe اختیاریه — وقتی از Discovery باز می‌شه پاس داده می‌شه (برای
// لایک/رد از همین‌جا)، ولی وقتی از صفحه‌ی چت باز می‌شه (کسی که از قبل متچ
// شده) لازم نیست، پس دکمه‌ها اصلاً نشون داده نمی‌شن.
class ProfileDetailSheet extends StatelessWidget {
  final DiscoveryCandidate candidate;
  final Map<String, String> promptTextMap;
  final Map<String, String> interestLabelMap;
  final ScrollController scrollController;
  final void Function(String direction)? onSwipe;

  /// نگه داشتنِ دکمه‌ی روشنِ لایک/سوپرلایک → برداشتنِ لایک.
  final VoidCallback? onRemoveLike;

  const ProfileDetailSheet({
    super.key,
    required this.candidate,
    required this.promptTextMap,
    required this.interestLabelMap,
    required this.scrollController,
    this.onSwipe,
    this.onRemoveLike,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        if (candidate.photos.isNotEmpty)
          SizedBox(
            height: 320,
            child: PageView(
              children: candidate.photos
                  .map((p) => ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network('$backendBaseUrl${p.url}', fit: BoxFit.cover),
                      ))
                  .toList(),
            ),
          ),
        const SizedBox(height: 16),
        Text('${candidate.name}, ${candidate.age}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        if (candidate.distanceKm != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('${candidate.distanceKm} کیلومتر دورتر',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
        if (candidate.bio.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(candidate.bio),
        ],
        if (candidate.interests.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: candidate.interests
                .map((id) => Chip(label: Text(interestLabelMap[id] ?? id)))
                .toList(),
          ),
        ],
        for (final prompt in candidate.prompts) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(promptTextMap[prompt.promptId] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(prompt.answer),
                ],
              ),
            ),
          ),
        ],
        if (onSwipe != null) ...[
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton.icon(
                onPressed: () => onSwipe!('pass'),
                icon: const Icon(Icons.close, color: Colors.red),
                label: const Text('رد', style: TextStyle(color: Colors.red)),
              ),
              _interestButton(
                lit: candidate.previousDirection == 'super_like',
                color: SwipeColors.superLike,
                icon: Icons.star,
                label: 'سوپرلایک',
                direction: 'super_like',
              ),
              _interestButton(
                lit: candidate.previousDirection == 'like',
                color: SwipeColors.like,
                icon: Icons.favorite,
                label: 'لایک',
                direction: 'like',
              ),
            ],
          ),
          if (onRemoveLike != null &&
              (candidate.previousDirection == 'like' ||
                  candidate.previousDirection == 'super_like')) ...[
            const SizedBox(height: 8),
            const Text(
              'برای برداشتنِ لایک، دکمه‌ی روشن رو نگه دار.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  /// دکمه‌ی لایک/سوپرلایک: اگه از قبل ثبت شده «روشن» (توپر) نشون داده می‌شه؛
  /// زدنش فقط کارت رو رد می‌کنه، نگه داشتنش لایک رو برمی‌داره.
  Widget _interestButton({
    required bool lit,
    required Color color,
    required IconData icon,
    required String label,
    required String direction,
  }) {
    if (lit) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
        onPressed: () => onSwipe!(direction),
        onLongPress: onRemoveLike,
        icon: Icon(icon),
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color)),
      onPressed: () => onSwipe!(direction),
      icon: Icon(icon, color: color),
      label: Text(label, style: TextStyle(color: color)),
    );
  }
}
