// داده و مدل‌های صفحه‌ی «لایک‌ها» — دقیقاً بر اساسِ ویژگی‌های صفحه‌ی
// «Likes You» تیندر:
//   • یه گریدِ دوستونه‌ی ناهم‌اندازه (staggered) از همه‌ی کسایی که
//     پروفایلِ کاربر رو لایک کرده‌ان.
//   • اگه کاربر پرمیوم نباشه، همه‌ی عکس‌ها بلور و قفلن؛ فقط تعدادِ
//     لایک‌ها بالای صفحه نشون داده می‌شه (نه هویتشون).
//   • هر کارت یه بج داره: قلبِ طلایی برای لایکِ معمولی، ستاره‌ی آبی
//     برای Super Like (با یه حاشیه‌ی آبی دورِ کارت).
//   • نقطه‌ی سبزِ کنارِ اسم یعنی «اخیراً آنلاین بوده».
//   • تپ روی کارتِ قفل‌شده = شیتِ آپگرید؛ تپ روی کارتِ بازشده = پروفایلِ
//     کامل با دکمه‌ی Pass/Like — چون طرف از قبل لایک‌مون کرده، لایک‌کردن
//     همون لحظه مچ می‌شه (بدونِ صف‌کشیدنِ توی گریدِ سواپِ اصلی).
//
// این فایل فقط مدل + یه دیتای موکِ نمونه رو داره تا UI بدونِ بک‌اند هم
// قابلِ تست باشه؛ fetchLikesYou رو با اندپوینتِ واقعیِ بک‌اندت (مثلاً
// GET /api/likes-you) پر کن.

import '../models/profile_models.dart';

class LikeEntry {
  final DiscoveryCandidate candidate;
  final bool isSuperLike;
  final DateTime? likedAt;

  LikeEntry({
    required this.candidate,
    this.isSuperLike = false,
    this.likedAt,
  });

  factory LikeEntry.fromJson(Map<String, dynamic> json) => LikeEntry(
        candidate: DiscoveryCandidate.fromJson(json),
        isSuperLike: json['is_super_like'] ?? json['super_like'] ?? false,
        likedAt: DateTime.tryParse('${json['liked_at'] ?? ''}'),
      );
}

/// TODO: این رو با یه GET واقعی به بک‌اندت جایگزین کن، مثلاً:
///   final res = await apiClient.get('/api/likes-you');
///   return (res['results'] as List).map((e) => LikeEntry.fromJson(e)).toList();
/// فعلاً موکه که صفحه بدونِ بک‌اند هم قابلِ دیدن و تست باشه.
Future<List<LikeEntry>> fetchLikesYou() async {
  await Future.delayed(const Duration(milliseconds: 400));
  return kMockLikes;
}

/// مسیرِ url تو Photo نسبیه (مثلِ '/uploads/xxx.jpg')؛ این تابع رو با
/// همون هلپرِ base-url ای که برای عکس‌های DiscoveryCandidate تو بقیه‌ی
/// اپ داری جایگزین کن (مثلاً `'$backendBaseUrl$relativeUrl'`).
String resolveLikePhotoUrl(String relativeUrl) => relativeUrl;

final List<LikeEntry> kMockLikes = List.generate(9, (i) {
  const names = [
    'نگار', 'پارسا', 'المیرا', 'کیانا', 'آرمین',
    'ترانه', 'سپهر', 'یاسمن', 'بهراد',
  ];
  return LikeEntry(
    candidate: DiscoveryCandidate(
      publicId: 'mock_like_$i',
      name: names[i],
      age: 21 + i,
      bio: '',
      interests: const [],
      prompts: const [],
      photos: [Photo(id: 'p$i', url: '', position: 0)],
      distanceKm: null,
      activityStatus: i % 3 == 0 ? 'active' : null,
    ),
    isSuperLike: i % 4 == 0,
    likedAt: DateTime.now().subtract(Duration(hours: i * 3)),
  );
});
