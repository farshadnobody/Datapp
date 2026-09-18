import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../api_client.dart';

// این صفحه فقط برای دیباگ/تست سریعه (مرحله‌ی اول نقشه راه) — از منوی اصلی
// اپ لینک نمی‌شه، ولی نگهش داشتیم چون برای چک کردن سریع اتصال به بک‌اند مفیده.
class ConnectionTestScreen extends StatefulWidget {
  const ConnectionTestScreen({super.key});

  @override
  State<ConnectionTestScreen> createState() => _ConnectionTestScreenState();
}

class _ConnectionTestScreenState extends State<ConnectionTestScreen> {
  String _statusMessage = '';
  bool _loading = false;
  bool? _success;

  Future<void> _testConnection() async {
    setState(() {
      _loading = true;
      _statusMessage = '';
      _success = null;
    });

    try {
      final response = await http
          .get(Uri.parse('$backendBaseUrl/api/health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _success = true;
          _statusMessage = 'متصل شد ✅  (status: ${data['status']})';
        });
      } else {
        setState(() {
          _success = false;
          _statusMessage = 'خطا از سرور: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _success = false;
        _statusMessage = 'اتصال برقرار نشد ❌\n$e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تست اتصال')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _loading ? null : _testConnection,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('تست اتصال'),
              ),
              const SizedBox(height: 24),
              if (_statusMessage.isNotEmpty)
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: _success == true ? Colors.green : Colors.red,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
