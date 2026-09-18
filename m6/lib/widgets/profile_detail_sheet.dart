import 'package:flutter/material.dart';
import '../api_client.dart';
import '../models/profile_models.dart';

// نکته: onSwipe اختیاریه — وقتی از Discovery باز می‌شه پاس داده می‌شه (برای
// لایک/رد از همین‌جا)، ولی وقتی از صفحه‌ی چت باز می‌شه (کسی که از قبل متچ
// شده) لازم نیست، پس دکمه‌ها اصلاً نشون داده نمی‌شن.
class ProfileDetailSheet extends StatelessWidget {
  final DiscoveryCandidate candidate;
  final Map<String, String> promptTextMap;
  final Map<String, String> interestLabelMap;
  final ScrollController scrollController;
  final void Function(String direction)? onSwipe;

  const ProfileDetailSheet({
    super.key,
    required this.candidate,
    required this.promptTextMap,
    required this.interestLabelMap,
    required this.scrollController,
    this.onSwipe,
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
              OutlinedButton.icon(
                onPressed: () => onSwipe!('super_like'),
                icon: const Icon(Icons.star, color: Colors.blue),
                label: const Text('سوپرلایک', style: TextStyle(color: Colors.blue)),
              ),
              ElevatedButton.icon(
                onPressed: () => onSwipe!('like'),
                icon: const Icon(Icons.favorite),
                label: const Text('لایک'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}
