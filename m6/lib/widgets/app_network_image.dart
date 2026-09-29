import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

/// آدرسِ نسخه‌ی کوچیکِ یه عکسِ پابلیک: ".../<id>.jpg" → ".../<id>_t.jpg" (بک‌اند
/// موقع آپلود می‌سازتش). برای هر چیزِ دیگه‌ای (عکس خصوصی، آدرسِ غیرِ uploads) همون
/// آدرس برمی‌گرده.
String photoThumbUrl(String url) {
  if (!url.contains('/uploads/') || url.contains('/uploads/private')) return url;
  if (url.endsWith('_t.jpg')) return url;
  final slash = url.lastIndexOf('/');
  final dot = url.lastIndexOf('.');
  if (dot <= slash) return url;
  return '${url.substring(0, dot)}_t.jpg';
}

/// کشِ دائمیِ عکس‌ها روی گوشی: ۲۰ روز اعتبار (از آخرین باری که دیده شد) + سقفِ حجمِ ۱ گیگابایت.
class AppImageCache {
  AppImageCache._();

  static const String _key = 'appPhotoCache';
  static const int maxBytes = 1024 * 1024 * 1024; // سقف: ۱ گیگابایت
  static const int trimTargetBytes = 600 * 1024 * 1024; // بعد از پاکسازی: ~۶۰۰ مگابایت

  static final JsonCacheInfoRepository _repo =
      JsonCacheInfoRepository(databaseName: _key);

  // نکته: flutter_cache_manager سقفِ حجم نداره، فقط سقفِ تعداد؛ اون رو خیلی
  // بزرگ گذاشتیم (عملاً بی‌اثر) و سقفِ حجم رو خودمون تو trimIfTooBig اعمال می‌کنیم.
  static final CacheManager manager = CacheManager(
    Config(
      _key,
      stalePeriod: const Duration(days: 20),
      maxNrOfCacheObjects: 100000,
      repo: _repo,
    ),
  );

  static Future<int> _dirSize() async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/$_key');
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final e in dir.list(recursive: true, followLinks: false)) {
      if (e is File) total += await e.length();
    }
    return total;
  }

  /// اگه حجمِ کش از ۱ گیگابایت رد شده بود، «قدیمی‌ترین» عکس‌ها (بر اساسِ آخرین
  /// باری که دیده شدن) پاک می‌شن تا حجم به ~۶۰۰ مگابایت برسه (یعنی ~۴۰۰ مگ پاک
  /// می‌شه، نه کلِ کش). یه بار موقع شروعِ اپ، تو پس‌زمینه صدا زده می‌شه.
  static Future<void> trimIfTooBig() async {
    try {
      var remaining = await _dirSize();
      if (remaining <= maxBytes) return;

      await _repo.open();
      final objects = await _repo.getAllObjects();
      DateTime when(CacheObject o) => (o.touched as DateTime?) ?? o.validTill;
      objects.sort((a, b) => when(a).compareTo(when(b))); // قدیمی‌ترین اول

      for (final o in objects) {
        if (remaining <= trimTargetBytes) break;
        var size = 0;
        final info = await manager.getFileFromCache(o.key);
        if (info != null && await info.file.exists()) size = await info.file.length();
        await manager.removeFile(o.key);
        remaining -= size;
      }
    } catch (_) {}
  }

  /// موقع خروج از حساب: عکسِ آدم‌های دیگه نباید رو گوشی بمونه.
  static Future<void> clear() async {
    try {
      await manager.emptyCache();
    } catch (_) {}
  }
}

/// برای precacheImage.
ImageProvider appImageProvider(String url) =>
    CachedNetworkImageProvider(url, cacheManager: AppImageCache.manager);

/// جایگزینِ Image.network برای عکس‌های پابلیک: کشِ دائمی + (اختیاری) نسخه‌ی
/// کوچیک + (اختیاری) «بارگذاریِ تدریجی»: تا نسخه‌ی کاملِ عکس بیاد، نسخه‌ی کوچیک
/// (که معمولاً از قبل کش شده) نشون داده می‌شه.
class AppNetworkImage extends StatelessWidget {
  final String url;
  final bool thumb;
  final bool progressive;
  final bool keepOldWhileLoading;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Color placeholderColor;
  final WidgetBuilder? errorBuilder;

  const AppNetworkImage(
    this.url, {
    super.key,
    this.thumb = false,
    this.progressive = false,
    this.keepOldWhileLoading = false,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholderColor = const Color(0xFF1B1C1F),
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final target = thumb ? photoThumbUrl(url) : url;
    final thumbForPlaceholder = photoThumbUrl(url);

    return CachedNetworkImage(
      imageUrl: target,
      cacheManager: AppImageCache.manager,
      fit: fit,
      width: width,
      height: height,
      useOldImageOnUrlChange: keepOldWhileLoading,
      fadeInDuration: const Duration(milliseconds: 120),
      fadeOutDuration: const Duration(milliseconds: 120),
      placeholder: (context, _) {
        if (progressive && !thumb && thumbForPlaceholder != url) {
          return CachedNetworkImage(
            imageUrl: thumbForPlaceholder,
            cacheManager: AppImageCache.manager,
            fit: fit,
            width: width,
            height: height,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            filterQuality: FilterQuality.low,
            placeholder: (_, __) => ColoredBox(color: placeholderColor),
            errorWidget: (_, __, ___) => ColoredBox(color: placeholderColor),
          );
        }
        return ColoredBox(color: placeholderColor);
      },
      errorWidget: (context, _, __) {
        // نسخه‌ی کوچیک وجود نداشت (مثلاً عکسِ WebP): به نسخه‌ی اصلی برگرد.
        if (thumb && target != url) {
          return AppNetworkImage(
            url,
            fit: fit,
            width: width,
            height: height,
            placeholderColor: placeholderColor,
            errorBuilder: errorBuilder,
          );
        }
        return errorBuilder?.call(context) ??
            ColoredBox(
              color: placeholderColor,
              child: const Center(
                child: Icon(Icons.broken_image_outlined, color: Color(0xFF55565B)),
              ),
            );
      },
    );
  }
}
