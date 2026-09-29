import 'dart:async';
import 'package:flutter/material.dart';
import '../api_client.dart';
import '../connection_monitor.dart';

// یه نوار نازک بالای صفحه که هر چند ثانیه یک‌بار با بک‌اند چک می‌کنه اتصال
// برقراره یا نه، و رنگ/متنش رو بر همون اساس عوض می‌کنه.
class ConnectionStatusBanner extends StatefulWidget {
  const ConnectionStatusBanner({super.key});

  @override
  State<ConnectionStatusBanner> createState() =>
      _ConnectionStatusBannerState();
}

class _ConnectionStatusBannerState extends State<ConnectionStatusBanner> {
  // وضعیت از ConnectionMonitor میاد (هر درخواستِ واقعیِ اپ اون رو به‌روز می‌کنه)،
  // پس وقتی وصلیم هیچ درخواستِ چکی نمی‌ره. فقط وقتی «قطع» شد هر ۱۰ ثانیه
  // /api/health رو می‌زنیم تا برگشتنِ اتصال رو بفهمیم.
  bool? get _connected => ConnectionMonitor.online.value;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    ConnectionMonitor.online.addListener(_onChanged);
    _syncTimer();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    _syncTimer();
  }

  void _syncTimer() {
    if (_connected == false) {
      _retryTimer ??= Timer.periodic(
        const Duration(seconds: 10),
        (_) => ApiClient.checkHealth(),
      );
    } else {
      _retryTimer?.cancel();
      _retryTimer = null;
    }
  }

  @override
  void dispose() {
    ConnectionMonitor.online.removeListener(_onChanged);
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // تا اولین چک انجام نشده، چیزی نشون نده تا صفحه چشمک نزنه. وقتی هم که
    // اتصال برقراره چیزی نشون نمی‌دیم (نوار سبز بالای صفحه‌ی Swipe با ظاهر
    // تیندر جور نبود)؛ فقط وقتی قطع بشه نوار قرمز میاد. اگه نوار سبز رو تو
    // دیباگ می‌خوای، شرط رو به `_connected == null` برگردون.
    if (_connected == null || _connected == true) {
      return const SizedBox.shrink();
    }

    final connected = _connected!;
    return Material(
      color: connected ? Colors.green.shade600 : Colors.red.shade600,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                connected ? Icons.cloud_done : Icons.cloud_off,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                connected ? 'ارتباط با سرور برقراره' : 'ارتباط با سرور قطع شد',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
