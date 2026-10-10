import 'package:flutter/material.dart';

import '../style/app_colors.dart';
import 'boost_screen.dart';
import 'boost_state.dart';

/// صاعقه‌ی هدرِ سواپ: شیتِ تأییدِ فعال‌سازی. موجودی نداره → مسیرِ «خرید»؛ can_buy=false →
/// دکمه‌ی خرید غیرفعال با پیام (فعال‌سازیِ بوستِ موجود هیچ‌وقت بسته نمی‌شه).
Future<void> showBoostSheet(BuildContext context) async {
  await BoostState.instance.refresh();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppDark.cardAlt,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => const _BoostSheet(),
  );
}

class _BoostSheet extends StatefulWidget {
  const _BoostSheet();
  @override
  State<_BoostSheet> createState() => _BoostSheetState();
}

class _BoostSheetState extends State<_BoostSheet> {
  bool _busy = false;
  String? _error;

  BoostState get _s => BoostState.instance;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = boostErrorMessage(e));
      await _s.refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListenableBuilder(
        listenable: _s,
        builder: (context, _) {
          final active = _s.active;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Icon(Icons.bolt, color: Color(0xFFF4B0EC), size: 44),
                const SizedBox(height: 10),
                Text(active != null ? 'بوستت فعاله' : 'پروفایلت رو بوست کن',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  active != null
                      ? '${active.views} از ${active.viewBudget} بازدید'
                      : 'پروفایلت تا ${_s.viewBudget} بازدید (حداکثر ${_s.durationHours} ساعت) تو اولویتِ نمایش بقیه قرار می‌گیره. '
                          'بازدید یعنی کسی که کارتت رو لایک، رد یا سوپرلایک کنه.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppDark.muted, height: 1.6),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppDark.warning)),
                ],
                const SizedBox(height: 16),
                if (active != null)
                  _button('دیدنِ آمار', () {
                    Navigator.pop(context);
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BoostScreen()));
                  })
                else if (_s.credits > 0)
                  _button(_busy ? 'در حال فعال‌سازی...' : 'فعال‌سازی بوست (موجودی: ${_s.credits})', () async {
                    await _run(() async {
                      await _s.activate();
                      if (mounted) Navigator.pop(context);
                    });
                  }, enabled: !_busy && _s.enabled)
                else ...[
                  _button(_busy ? 'لطفاً صبر کن...' : 'خرید بوست', () => _run(_s.buy),
                      enabled: _s.canBuy && _s.enabled && !_busy),
                  if (!_s.canBuy || !_s.enabled)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_s.enabled ? 'فعلاً امکان خرید بوست جدید نیست.' : 'بوست فعلاً غیرفعاله.',
                          textAlign: TextAlign.center, style: const TextStyle(color: AppDark.muted)),
                    ),
                ],
                if (active == null && _s.credits > 0 && !_s.enabled)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('بوست فعلاً غیرفعاله؛ موجودیت سر جاشه و بعداً می‌تونی فعالش کنی.',
                        textAlign: TextAlign.center, style: TextStyle(color: AppDark.muted)),
                  ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BoostScreen()));
                  },
                  child: const Text('تاریخچه‌ی بوست‌ها', style: TextStyle(color: AppDark.muted)),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _button(String label, VoidCallback onTap, {bool enabled = true}) => ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          disabledBackgroundColor: const Color(0xFF3A3A3E),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      );
}
