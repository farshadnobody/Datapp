import 'dart:async';
import 'package:flutter/material.dart';
import '../api_client.dart';

// یه نوار نازک بالای صفحه که هر چند ثانیه یک‌بار با بک‌اند چک می‌کنه اتصال
// برقراره یا نه، و رنگ/متنش رو بر همون اساس عوض می‌کنه.
class ConnectionStatusBanner extends StatefulWidget {
  const ConnectionStatusBanner({super.key});

  @override
  State<ConnectionStatusBanner> createState() =>
      _ConnectionStatusBannerState();
}

class _ConnectionStatusBannerState extends State<ConnectionStatusBanner> {
  bool? _connected; // null = هنوز چک نکردیم
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _check();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _check());
  }

  Future<void> _check() async {
    final result = await ApiClient.checkHealth();
    // فقط وقتی وضعیت واقعاً عوض شده rebuild کن — نه هر ۵ ثانیه بی‌دلیل.
    if (mounted && result != _connected) {
      setState(() => _connected = result);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // تا اولین چک انجام نشده، چیزی نشون نده تا صفحه چشمک نزنه.
    if (_connected == null) {
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
