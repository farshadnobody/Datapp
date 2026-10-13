import '../api_client.dart';
import '../models/profile_models.dart';
import 'card_cache.dart';
import 'discovery_queue.dart';

/// سرور گفته این پروفایل وجود نداره (کاربر بن شده، حذف شده، یا بلاک شده): کارتش رو از
/// کش و از همه‌ی صف‌های ذخیره‌شده پاک می‌کنیم تا دوباره نشون داده نشه. هیچ‌وقت خطا نمی‌ده.
Future<void> purgeGoneCard(String publicId) async {
  try {
    await CardCache.instance.remove(publicId);
    await DiscoveryQueueStore.instance.removeEverywhere(publicId);
  } catch (_) {}
}

/// بازکردنِ پروفایلِ یه کارت با شناسه‌ی عمومی (جست‌وجو با آیدی، پروفایلِ متچ، ...) —
/// همون منطقِ نسخه‌ی فلشِ کارتِ سواپ:
///  ۱) کارت تو CardCache نیست → کارتِ کامل (با جزئیات) از سرور؛ تو کش ذخیره می‌شه.
///  ۲) کارت تو کشه → نسخه‌ش (و اینکه جزئیاتش رو داریم یا نه) همراهِ id می‌ره:
///     - نسخه یکی و جزئیات داریم → سرور هیچ‌چیزِ کارت نمی‌فرسته، از کش استفاده می‌شه.
///     - نسخه یکی ولی جزئیات نداریم → فقط جزئیات می‌آد و تو کش ذخیره می‌شه.
///     - نسخه‌ی اپ کهنه → کارتِ کامل می‌آد؛ هم نمایش هم کش به‌روز می‌شن.
Future<DiscoveryCandidate> resolveCard(String publicId) async {
  try {
    return await _resolveCard(publicId);
  } on ApiException catch (e) {
    if (e.code == 'profile_not_found') await purgeGoneCard(publicId);
    rethrow;
  }
}

Future<DiscoveryCandidate> _resolveCard(String publicId) async {
  final cache = CardCache.instance;
  await cache.ensureLoaded();
  final cached = cache.getAny(publicId);

  if (cached == null) {
    final json = await ApiClient.fetchDiscoveryProfileRaw(publicId);
    final card = DiscoveryCandidate.fromJson(json);
    card.detailsChecked = true;
    await cache.putAll([card]);
    return card;
  }

  final json = await ApiClient.fetchDiscoveryProfileRaw(
    publicId,
    version: cached.version,
    hasDetails: cached.detailsLoaded,
  );
  if (json['full'] == true) {
    final card = DiscoveryCandidate.fromJson(json);
    card.detailsChecked = true;
    await cache.putAll([card]);
    return card;
  }
  final changed = cached.applyServerProfile(json);
  cached.detailsChecked = true;
  if (changed) await cache.putAll([cached]);
  return cached;
}
