import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../network_config.dart';

enum PaywallReason { superLike, likes, rewind, likeLimit, chatHistory }

/// شیتِ «این قابلیت مخصوصِ اشتراکِ ویژه‌ست».
Future<void> showPremiumPaywall(BuildContext context, PaywallReason reason) {
  final (icon, color, title, message) = switch (reason) {
    PaywallReason.superLike => (
        Icons.star_rounded,
        const Color(0xFF3D9CF0),
        'سوپرلایک مخصوصِ اشتراکِ ویژه‌ست',
        'با اشتراکِ ویژه هر روز چند سوپرلایک داری و طرف می‌فهمه که خاص بوده.',
      ),
    PaywallReason.likes => (
        Icons.favorite,
        const Color(0xFFFFC629),
        'این بخش مخصوصِ اشتراکِ ویژه‌ست',
        'با اشتراکِ ویژه می‌تونی ببینی کی لایک و سوپرلایکت کرده.',
      ),
    PaywallReason.rewind => (
        Icons.replay_rounded,
        const Color(0xFFFFC629),
        'برگشتن به کارتِ قبلی مخصوصِ اشتراکِ ویژه‌ست',
        'اشتباهی رد کردی؟ با اشتراکِ ویژه می‌تونی آخرین کارت رو برگردونی.',
      ),
    PaywallReason.chatHistory => (
        Icons.history_rounded,
        const Color(0xFFFFC629),
        'تاریخچه‌ی کاملِ چت مخصوصِ اشتراکِ ویژه‌ست',
        'کاربرِ رایگان فقط پیام‌های اخیر رو می‌بینه. با اشتراکِ ویژه همه‌ی پیام‌های قدیمی هم باز می‌شن.',
      ),
    PaywallReason.likeLimit => (
        Icons.favorite,
        const Color(0xFFFF4D6D),
        'لایک‌های امروزت تموم شد',
        'فردا دوباره لایک داری. با اشتراکِ ویژه لایکِ نامحدود می‌گیری.',
      ),
  };
  return showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1C1C1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC629),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    openUpgrade(context);
                  },
                  child: const Text('خرید اشتراک',
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('شاید بعداً', style: TextStyle(color: Color(0xFF8E8E93))),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// رفتن به صفحه‌ی خریدِ اشتراک. روشِ پرداخت هنوز مشخص نشده؛ وقتی [kUpgradeUrl]
/// (تو network_config.dart) پر بشه، همون لینک (مثلاً ربات بله یا درگاه) باز می‌شه.
Future<void> openUpgrade(BuildContext context) async {
  if (kUpgradeUrl.isNotEmpty) {
    try {
      final ok = await launchUrl(Uri.parse(kUpgradeUrl), mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (_) {}
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(
      content: Text('خرید اشتراک به‌زودی فعال می‌شه.'),
      duration: Duration(seconds: 3),
    ));
}
