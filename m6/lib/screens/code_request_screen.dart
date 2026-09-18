import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api_client.dart';

class CodeRequestScreen extends StatefulWidget {
  const CodeRequestScreen({super.key});

  @override
  State<CodeRequestScreen> createState() => _CodeRequestScreenState();
}

class _CodeRequestScreenState extends State<CodeRequestScreen> {
  final _phoneController = TextEditingController();
  bool _loading = false;
  String? _errorText;
  RequestCodeResult? _result;

  Future<void> _submit() async {
    HapticFeedback.lightImpact();
    setState(() {
      _loading = true;
      _errorText = null;
      _result = null;
    });

    try {
      final result = await ApiClient.requestCode(_phoneController.text.trim());
      setState(() => _result = result);
    } on NetworkException {
      setState(() => _errorText =
          'ارتباط با سرور برقرار نشد. مطمئن شو بک‌اند روشنه و آدرس سرور تو api_client.dart درسته.');
    } on ApiException catch (e) {
      setState(() => _errorText = e.code == 'invalid_phone'
          ? 'شماره وارد شده نامعتبره. دوباره چک کن.'
          : 'خطایی رخ داد. دوباره امتحان کن.');
    } catch (e) {
      setState(() => _errorText = 'خطایی رخ داد. دوباره امتحان کن.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openBaleBot() async {
    if (_result == null) return;
    final uri = Uri.parse(_result!.deepLink);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('باز کردن ربات بله ممکن نشد.')),
      );
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ثبت‌نام یا فراموشی رمز')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              enabled: _result == null,
              decoration: const InputDecoration(
                labelText: 'شماره موبایل',
                border: OutlineInputBorder(),
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Text(_errorText!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            if (_result == null)
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('دریافت کد', style: TextStyle(fontSize: 16)),
                      ),
              )
            else
              _buildResultCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    // این متن، چه شماره از قبل ثبت‌نام کرده باشه چه نه، دقیقاً همینه — عمداً
    // یکسانه تا کسی نتونه از این صفحه بفهمه چه شماره‌هایی تو سایت ثبت‌نام کردن.
    final result = _result!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'کد زیر برات آماده شد. اعتبار: ۱۵ دقیقه.',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            SelectableText(
              result.code,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openBaleBot,
              icon: const Icon(Icons.send),
              label: const Text('باز کردن ربات بله'),
            ),
            const SizedBox(height: 12),
            const Text(
              'یا این کد رو دستی برای ربات @TrustVerifyBot در بله بفرست تا نام کاربری و رمز عبورت رو دریافت کنی.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
