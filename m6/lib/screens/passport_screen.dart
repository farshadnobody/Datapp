import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../api_client.dart';
import '../style/app_colors.dart';
import '../subscription/premium_paywall.dart';
import '../subscription/subscription_state.dart';
import 'location_picker_screen.dart';

/// موقعیتِ مکانی (Passport، مثل Tinder): کاربر یا موقعیتِ واقعیِ GPS رو به اشتراک می‌ذاره،
/// یا (فقط اشتراکی) یه نقطه‌ی دلخواه روی نقشه انتخاب می‌کنه. چکِ اشتراک سمتِ سرور هم هست.
/// وقتی چیزی عوض بشه با `true` برمی‌گرده تا صفحه‌ی کشف دوباره لود بشه.
class PassportScreen extends StatefulWidget {
  const PassportScreen({super.key});

  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<PassportScreen> {
  PassportState? _state;
  bool _loading = true;
  bool _busy = false;
  bool _changed = false;
  String? _error;

  bool get _premium => _state?.isPremium ?? SubscriptionState.instance.isPremium;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await ApiClient.getPassportState();
      if (mounted) setState(() => _state = s);
    } on NetworkException {
      if (mounted) setState(() => _error = 'ارتباط با سرور برقرار نشد.');
    } catch (_) {
      if (mounted) setState(() => _error = 'دریافت وضعیت موقعیت با مشکل مواجه شد.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<PassportState> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final s = await action();
      _changed = true;
      if (mounted) setState(() => _state = s);
    } on ApiException catch (e) {
      if (e.code == 'premium_required' && mounted) {
        await showPremiumPaywall(context, PaywallReason.passport);
        await _load();
      } else if (mounted) {
        setState(() => _error = 'ذخیره‌ی موقعیت با مشکل مواجه شد.');
      }
    } on NetworkException {
      if (mounted) setState(() => _error = 'ارتباط با سرور برقرار نشد.');
    } catch (_) {
      if (mounted) setState(() => _error = 'ذخیره‌ی موقعیت با مشکل مواجه شد.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseReal() async {
    if (_busy || _state == null || !_state!.isCustom) return;
    HapticFeedback.selectionClick();
    await _run(ApiClient.useRealLocation);
  }

  Future<void> _chooseCustom() async {
    if (_busy) return;
    HapticFeedback.selectionClick();
    if (!_premium) {
      await showPremiumPaywall(context, PaywallReason.passport);
      return;
    }
    final s = _state;
    final start = (s?.latitude != null && s?.longitude != null)
        ? ll.LatLng(s!.latitude!, s.longitude!)
        : null;
    final picked = await Navigator.of(context).push<ll.LatLng>(
      MaterialPageRoute(builder: (_) => LocationPickerScreen(initialCenter: start)),
    );
    if (picked == null || !mounted) return;
    await _run(() => ApiClient.useCustomLocation(picked.latitude, picked.longitude));
  }

  @override
  Widget build(BuildContext context) {
    final custom = _state?.isCustom ?? false;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppDark.bg,
          appBar: AppBar(
            backgroundColor: AppDark.bg,
            elevation: 0,
            title: const Text('موقعیت مکانی',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_forward, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(_changed),
            ),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'فاصله‌ای که بقیه از تو می‌بینن و کاربرهایی که بهت نشون داده می‌شن، از روی همین موقعیته.',
                        style: TextStyle(color: AppDark.muted, fontSize: 14, height: 1.6),
                      ),
                    ),
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
                            TextButton(onPressed: _load, child: const Text('تلاش دوباره')),
                          ],
                        ),
                      ),
                    _OptionCard(
                      icon: Icons.my_location,
                      title: 'موقعیت واقعی من',
                      subtitle: 'فاصله‌ت از روی GPS گوشی‌ات حساب می‌شه.',
                      selected: !custom,
                      onTap: _chooseReal,
                    ),
                    const SizedBox(height: 12),
                    _OptionCard(
                      icon: Icons.public_rounded,
                      title: 'موقعیت دلخواه روی نقشه',
                      subtitle: custom
                          ? 'الان یه نقطه‌ی دلخواه فعاله. برای تغییرش بزن.'
                          : 'هر جای دنیا رو انتخاب کن و از اون‌جا کاربرها رو ببین.',
                      selected: custom,
                      premiumBadge: !_premium,
                      onTap: _chooseCustom,
                    ),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (!_premium)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Text(
                          'انتخاب موقعیتِ دلخواه مخصوصِ اشتراکِ ویژه‌ست. اگه اشتراکت تموم بشه، موقعیتت خودکار به موقعیتِ واقعی برمی‌گرده.',
                          style: TextStyle(color: AppDark.muted, fontSize: 12.5, height: 1.6),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool premiumBadge;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.premiumBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppDark.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? Colors.white : AppDark.border, width: selected ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(title,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                      if (premiumBadge) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC629),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('ویژه',
                              style: TextStyle(
                                  color: Colors.black, fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(color: AppDark.muted, fontSize: 13, height: 1.5)),
                ],
              ),
            ),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? Colors.white : AppDark.muted),
          ],
        ),
      ),
    );
  }
}
