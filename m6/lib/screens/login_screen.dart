import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_ui.dart';
import 'login_password_screen.dart';

// مرحله‌ی اول ورود: شماره موبایل با کد کشور جدا. بعد از «بعدی» می‌ره به
// مرحله‌ی رمز عبور.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();

  bool get _canSubmit => isPhoneComplete(_phoneController.text);

  void _next() {
    if (!_canSubmit) return;
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginPasswordScreen(
          phone: normalizeDigits(_phoneController.text.trim()),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      bottom: AuthPillButton(
        label: 'بعدی',
        onPressed: _canSubmit ? _next : null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthTitle('شماره موبایلت رو می‌دی؟'),
          const SizedBox(height: 28),
          AuthPhoneField(
            controller: _phoneController,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _next(),
          ),
          const SizedBox(height: 20),
          const AuthBodyText(
            'همون شماره‌ای رو وارد کن که باهاش ثبت‌نام کردی. تو مرحله‌ی بعد رمز عبورت رو می‌پرسیم.',
          ),
        ],
      ),
    );
  }
}
