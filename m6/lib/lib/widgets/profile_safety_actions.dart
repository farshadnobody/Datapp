import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../style/app_colors.dart';

/// دکمه‌های آخرِ پروفایلِ یه نفر: اشتراک‌گذاری، مسدودسازی و گزارش.
/// هم تو کارتِ سواپ استفاده می‌شه هم (دکمه‌ها و دیالوگ‌ها) تو صفحه‌ی پروفایلِ
/// متچ‌شده.
///
/// [onBlocked] بعد از مسدودسازیِ موفق صدا زده می‌شه (مثلاً برای برداشتنِ کارت
/// از Deck).
class ProfileSafetyActions extends StatelessWidget {
  final String publicId;
  final String name;
  final VoidCallback? onBlocked;

  const ProfileSafetyActions({
    super.key,
    required this.publicId,
    required this.name,
    this.onBlocked,
  });

  void _snack(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _share(BuildContext context) {
    Clipboard.setData(ClipboardData(text: 'پروفایل $name رو تو اپ ببین 👀'));
    _snack(context, 'متن اشتراک‌گذاری کپی شد.');
  }

  Future<void> _block(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppDark.cardAlt,
          title: Text('مسدود کردنِ $name؟', style: const TextStyle(color: Colors.white)),
          content: const Text(
            'دیگه همدیگه رو نمی‌بینید — نه تو چت، نه تو کشف.',
            style: TextStyle(color: AppDark.muted, height: 1.5),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('انصراف')),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('مسدود کن',
                  style: TextStyle(color: AppDark.warning, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ApiClient.blockUser(publicId);
      if (!context.mounted) return;
      onBlocked?.call();
    } catch (_) {
      if (!context.mounted) return;
      _snack(context, 'مسدودسازی با مشکل مواجه شد.');
    }
  }

  Future<void> _report(BuildContext context) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppDark.cardAlt,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: ReportReasonSheet(matchName: name),
      ),
    );
    if (reason == null || !context.mounted) return;
    try {
      await ApiClient.reportUser(publicId, reason: reason);
      if (!context.mounted) return;
      _snack(context, 'گزارشت ثبت شد — نگران نباش، طرف خبردار نمی‌شه.');
    } catch (_) {
      if (!context.mounted) return;
      _snack(context, 'ثبت گزارش با مشکل مواجه شد.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        ProfileActionButton(label: 'اشتراک‌گذاریِ پروفایلِ $name', onTap: () => _share(context)),
        const SizedBox(height: 10),
        ProfileActionButton(label: 'مسدودسازیِ $name', onTap: () => _block(context)),
        const SizedBox(height: 10),
        ProfileActionButton(label: 'گزارشِ $name', onTap: () => _report(context), danger: true),
      ],
    );
  }
}

class ProfileActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const ProfileActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppDark.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: danger ? AppDark.warning : Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class ReportReasonSheet extends StatelessWidget {
  final String matchName;
  const ReportReasonSheet({super.key, required this.matchName});

  static const _reasons = [
    ('inappropriate_content', 'محتوای نامناسب'),
    ('fake_profile', 'پروفایل جعلی'),
    ('harassment', 'آزار یا رفتار توهین‌آمیز'),
    ('scam', 'کلاه‌برداری یا اسپم'),
    ('underage', 'کمتر از سن مجاز به نظر می‌رسه'),
    ('other', 'دلیل دیگه'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('گزارشِ $matchName',
                style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('چرا می‌خوای گزارشش کنی؟', style: TextStyle(color: AppDark.muted, fontSize: 14)),
            const SizedBox(height: 12),
            for (final r in _reasons)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(r.$2, style: const TextStyle(color: Colors.white, fontSize: 15)),
                trailing: const Icon(Icons.chevron_left, color: AppDark.muted),
                onTap: () => Navigator.of(context).pop(r.$1),
              ),
          ],
        ),
      ),
    );
  }
}
