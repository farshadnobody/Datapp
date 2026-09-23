import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../style/app_colors.dart';

/// باتم‌شیتِ «Safety Toolkit» که از دکمه‌ی سه‌نقطه‌ی صفحه‌ی چت باز می‌شه.
/// نتیجه (Navigator.pop) اگه true باشه یعنی Unmatch/Block موفق بوده —
/// صفحه‌ی چت باید خودش رو ببنده و برگرده به لیست.
Future<bool?> showSafetyToolkitSheet(
  BuildContext context, {
  required String matchPublicId,
  required String matchName,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => SafetyToolkitSheet(matchPublicId: matchPublicId, matchName: matchName),
  );
}

class SafetyToolkitSheet extends StatelessWidget {
  final String matchPublicId;
  final String matchName;

  const SafetyToolkitSheet({super.key, required this.matchPublicId, required this.matchName});

  Future<void> _handleFeedback(BuildContext context) async {
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => _TextPromptDialog(
        title: 'بازخوردِ خصوصی',
        subtitle: 'تجربه‌ت با $matchName رو خصوصی برامون بنویس.',
        hint: 'مثلاً: مکالمه‌ی خوبی بود...',
        confirmLabel: 'ارسال',
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    if (!context.mounted) return;
    try {
      await ApiClient.sendMatchFeedback(matchPublicId, text.trim());
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ممنون از بازخوردت.')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ارسال بازخورد با مشکل مواجه شد.')));
    }
  }

  Future<void> _handleUnmatch(BuildContext context) async {
    final confirmed = await _confirm(
      context,
      title: 'Unmatch از $matchName؟',
      body: 'دیگه تو لیست متچ‌ها و چت‌هات نمی‌بینیدش، و طرف هم دیگه نمی‌تونه بهت پیام بده.',
      confirmLabel: 'Unmatch',
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    try {
      await ApiClient.unmatch(matchPublicId);
      if (!context.mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('این قابلیت هنوز آماده نیست.')));
    }
  }

  Future<void> _handleBlock(BuildContext context) async {
    final confirmed = await _confirm(
      context,
      title: 'مسدود کردنِ $matchName؟',
      body: 'دیگه همدیگه رو نمی‌بینید — نه تو چت، نه تو کشف.',
      confirmLabel: 'مسدود کن',
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    try {
      await ApiClient.blockUser(matchPublicId);
      if (!context.mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('این قابلیت هنوز آماده نیست.')));
    }
  }

  Future<void> _handleReport(BuildContext context) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppDark.cardAlt,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ReportReasonSheet(matchName: matchName),
    );
    if (reason == null) return;
    if (!context.mounted) return;
    try {
      await ApiClient.reportUser(matchPublicId, reason: reason);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('گزارشت ثبت شد. ما بهش رسیدگی می‌کنیم — نگران نباش، طرف خبردار نمی‌شه.')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ثبت گزارش با مشکل مواجه شد.')));
    }
  }

  void _handleSafetyCenter(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDark.cardAlt,
        title: const Text('مرکز امنیت', style: TextStyle(color: Colors.white)),
        content: const Text(
          'همیشه اولین قرارها رو تو مکان‌های عمومی بذار، اطلاعات شخصیت (آدرس، محل کار) رو زود به اشتراک نذار، و اگه '
          'چیزی حس امنیتت رو به خطر انداخت، همین‌جا گزارشش کن.',
          style: TextStyle(color: AppDark.muted, height: 1.6),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('متوجه شدم')),
        ],
      ),
    );
  }

  Future<bool?> _confirm(BuildContext context,
      {required String title, required String body, required String confirmLabel}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDark.cardAlt,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(body, style: const TextStyle(color: AppDark.muted, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('انصراف')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel, style: const TextStyle(color: AppDark.warning, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Container(
          decoration: BoxDecoration(color: AppDark.cardAlt, borderRadius: BorderRadius.circular(24)),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop();
                    },
                    child: const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFF2E2E31),
                      child: Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ),
                  const Expanded(
                    child: Text('Safety Toolkit',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 36),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(color: AppDark.card, borderRadius: BorderRadius.circular(18)),
                child: Column(
                  children: [
                    _ToolkitRow(
                      icon: Icons.chat_bubble_outline,
                      title: 'بازخورد',
                      subtitle: 'تجربه‌ت با این متچ رو خصوصی برامون بنویس.',
                      onTap: () => _handleFeedback(context),
                    ),
                    const _RowDivider(),
                    _ToolkitRow(
                      icon: Icons.heart_broken_outlined,
                      title: 'Unmatch از $matchName',
                      subtitle: 'دیگه علاقه‌ای نداری؟ از لیست متچ‌هات حذفش کن.',
                      onTap: () => _handleUnmatch(context),
                    ),
                    const _RowDivider(),
                    _ToolkitRow(
                      icon: Icons.flag_outlined,
                      title: 'گزارشِ $matchName',
                      subtitle: 'نگران نباش — طرف خبردار نمی‌شه.',
                      onTap: () => _handleReport(context),
                    ),
                    const _RowDivider(),
                    _ToolkitRow(
                      icon: Icons.block,
                      title: 'مسدودسازیِ $matchName',
                      subtitle: 'دیگه همدیگه رو نمی‌بینید.',
                      onTap: () => _handleBlock(context),
                    ),
                    const _RowDivider(),
                    _ToolkitRow(
                      icon: Icons.shield_outlined,
                      title: 'مرکز امنیت',
                      subtitle: 'سلامتت مهمه — راهنما و ابزارهای امنیتی رو اینجا ببین.',
                      onTap: () => _handleSafetyCenter(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider(color: AppDark.border, height: 1));
}

class _ToolkitRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolkitRow({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: AppDark.muted, fontSize: 13, height: 1.4)),
                ],
              ),
            ),
            const Icon(Icons.chevron_left, color: AppDark.muted),
          ],
        ),
      ),
    );
  }
}

/// دیالوگ ساده‌ی متنی — برای «بازخورد».
class _TextPromptDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final String hint;
  final String confirmLabel;

  const _TextPromptDialog({
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.confirmLabel,
  });

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppDark.cardAlt,
      title: Text(widget.title, style: const TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.subtitle, style: const TextStyle(color: AppDark.muted, height: 1.4)),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(color: AppDark.muted),
              filled: true,
              fillColor: AppDark.card,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('انصراف')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.confirmLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

/// شیتِ انتخاب دلیلِ گزارش.
class _ReportReasonSheet extends StatelessWidget {
  final String matchName;
  const _ReportReasonSheet({required this.matchName});

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
            Text('گزارشِ $matchName', style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
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
