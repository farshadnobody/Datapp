import 'package:flutter/material.dart';
import '../subscription/premium_paywall.dart';
import '../subscription/subscription_state.dart';

/// فیلترِ «حداکثر فاصله» — مخصوصِ اشتراکی (سرور هم همین رو اعمال می‌کنه).
/// اشتراکی: اسلایدر (۱ تا ۲۰۰ کیلومتر؛ ۲۰۰ = بدون محدودیت).
/// بقیه: یه ردیفِ قفل‌شده که با زدنش پی‌وال باز می‌شه.
class DistanceFilterControl extends StatelessWidget {
  final double? value; // null = بدون محدودیت
  final ValueChanged<double?> onChanged;
  final TextStyle? textStyle;

  const DistanceFilterControl({
    super.key,
    required this.value,
    required this.onChanged,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (!SubscriptionState.instance.isPremium) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showPremiumPaywall(context, PaywallReason.distanceFilter),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFFFFC629)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('حداکثر فاصله — مخصوصِ اشتراکِ ویژه', style: textStyle),
              ),
              const Icon(Icons.chevron_left_rounded, color: Color(0xFF8E8E93)),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value == null ? 'حداکثر فاصله: بدون محدودیت' : 'حداکثر فاصله: ${value!.round()} کیلومتر',
          style: textStyle,
        ),
        Slider(
          min: 1,
          max: 200,
          divisions: 199,
          value: value ?? 200,
          onChanged: (v) => onChanged(v >= 200 ? null : v),
        ),
      ],
    );
  }
}
