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
import 'likes_store.dart';
import '../bootstrap/bootstrap_service.dart';
import '../subscription/subscription_state.dart';

class LikeEntry {
  final DiscoveryCandidate candidate;
  final bool isSuperLike;
  final DateTime? likedAt;

  LikeEntry({
    required this.candidate,
    this.isSuperLike = false,
    this.likedAt,
    this.locked = false,
  });

  /// true یعنی کاربر اشتراک نداره و سرور هیچ اطلاعاتی از لایک‌کننده نفرستاده
  /// (فقط «یه لایک/سوپرلایکِ قفل‌شده»). candidate تو این حالت خالیه.
  final bool locked;

  factory LikeEntry.fromJson(Map<String, dynamic> json) {
    final isSuper = json['is_super_like'] ?? json['super_like'] ?? false;
    final likedAt = DateTime.tryParse('${json['liked_at'] ?? ''}');
    if (json['locked'] == true) {
      return LikeEntry(
        candidate: DiscoveryCandidate(
          publicId: '',
          name: '',
          age: 0,
          bio: '',
          interests: const [],
          prompts: const [],
          photos: const [],
          distanceKm: null,
        ),
        isSuperLike: isSuper,
        likedAt: likedAt,
        locked: true,
      );
    }
    return LikeEntry(
      candidate: DiscoveryCandidate.fromJson(json),
      isSuperLike: isSuper,
      likedAt: likedAt,
    );
  }
}

/// GET /api/likes/list — لیست واقعیِ کسایی که کاربرِ لاگین‌شده رو لایک/
/// سوپرلایک کرده‌ان ولی هنوز متچ نشدن (از بک‌اند، نه داده‌ی موک).
///
/// دیگه هر بار از سرور نمی‌گیره:
///  - اشتراکی: از [LikesStore] (صفحه‌های سی‌تاییِ IDها + CardCache). لود شدنش فقط با باز شدنِ
///    صفحه‌ی Likes شروع می‌شه (LikesScreen).
///  - رایگان: فقط «تعداد» (از bootstrap، حداکثر هر یک ساعت به‌روز می‌شه) → خانه‌های قفل.
Future<List<LikeEntry>> fetchLikesYou() async {
  if (SubscriptionState.instance.isPremium) {
    await LikesStore.instance.ensureLoaded();
    return LikesStore.instance.entries;
  }
  final total = AppCounters.instance.likesCount.clamp(0, 200);
  final supers = AppCounters.instance.superLikeCount;
  return [
    for (var i = 0; i < total; i++)
      LikeEntry.fromJson({'locked': true, 'is_super_like': i < supers}),
  ];
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
