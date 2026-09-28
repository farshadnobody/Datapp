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

import '../api_client.dart';
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

/// GET /api/likes/list — لیست واقعیِ کسایی که کاربرِ لاگین‌شده رو لایک/
/// سوپرلایک کرده‌ان ولی هنوز متچ نشدن (از بک‌اند، نه داده‌ی موک).
Future<List<LikeEntry>> fetchLikesYou() async {
  final rows = await ApiClient.fetchLikesList();
  return rows.map(LikeEntry.fromJson).toList();
}

/// مسیرِ url تو Photo نسبیه (مثلِ '/uploads/xxx.jpg')؛ اینجا به همون
/// backendBaseUrl ای که بقیه‌ی اپ برای عکس‌های DiscoveryCandidate استفاده
/// می‌کنه وصلش می‌کنیم.
String resolveLikePhotoUrl(String relativeUrl) {
  if (relativeUrl.isEmpty) return relativeUrl;
  if (relativeUrl.startsWith('http://') || relativeUrl.startsWith('https://')) {
    return relativeUrl;
  }
  return '$backendBaseUrl$relativeUrl';
}
