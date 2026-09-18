import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../auth_session.dart';
import '../push_notifications.dart';
import 'code_request_screen.dart';
import 'home_screen.dart';
import 'profile_setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _errorText;

  Future<void> _submit() async {
    HapticFeedback.lightImpact();
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final result = await ApiClient.login(
        _phoneController.text.trim(),
        _passwordController.text,
      );
      AuthSession.set(result.token, _phoneController.text.trim());
      PushNotifications.registerToken(); // منتظرش نمی‌مونیم؛ اگه نشد، بی‌خیال می‌شیم
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => result.hasProfile
              ? const HomeScreen()
              : const ProfileSetupScreen(),
        ),
        (route) => false,
      );
    } on NetworkException {
      setState(() => _errorText =
          'ارتباط با سرور برقرار نشد. مطمئن شو بک‌اند روشنه و آدرس سرور تو api_client.dart درسته.');
    } on ApiException {
      setState(() {
        // پیام یکسان برای شماره‌ی اشتباه و پسورد اشتباه — عمداً، تا کسی نفهمه
        // کدومش اشتباه بوده.
        _errorText = 'شماره موبایل یا رمز عبور اشتباهه.';
      });
    } catch (e) {
      setState(() => _errorText = 'خطایی رخ داد. دوباره امتحان کن.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ورود')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'شماره موبایل (نام کاربری)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'رمز عبور',
                border: OutlineInputBorder(),
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Text(_errorText!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
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
                      child: Text('ورود', style: TextStyle(fontSize: 16)),
                    ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CodeRequestScreen()),
                );
              },
              child: const Text('ثبت‌نام یا فراموشی رمز؟'),
            ),
          ],
        ),
      ),
    );
  }
}
