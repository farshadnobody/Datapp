import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../auth_session.dart';
import '../push_notifications.dart';
import 'auth_ui.dart';
import 'code_request_screen.dart';
import 'home_screen.dart';
import 'profile_setup_screen.dart';

// مرحله‌ی دوم ورود: رمز عبور. منطق لاگین همون قبلیه (ApiClient.login).
class LoginPasswordScreen extends StatefulWidget {
  final String phone;
  const LoginPasswordScreen({super.key, required this.phone});

  @override
  State<LoginPasswordScreen> createState() => _LoginPasswordScreenState();
}

class _LoginPasswordScreenState extends State<LoginPasswordScreen> {
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _errorText;

  bool get _canSubmit => _passwordController.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit || _loading) return;
    HapticFeedback.lightImpact();
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final result = await ApiClient.login(
        widget.phone,
        _passwordController.text,
      );
      // توکن روی گوشی ذخیره می‌شه تا با بستن اپ لاگین بمونه.
      await AuthSession.set(result.token, widget.phone,
          hasProfile: result.hasProfile);
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
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      bottom: AuthPillButton(
        label: 'ورود',
        loading: _loading,
        onPressed: _canSubmit ? _submit : null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthTitle('رمز عبورت رو وارد کن'),
          const SizedBox(height: 12),
          Text(
            widget.phone,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.start,
            style: const TextStyle(
              fontSize: 16,
              color: AuthColors.secondaryText,
            ),
          ),
          const SizedBox(height: 16),
          AuthUnderlineField(
            controller: _passwordController,
            hint: 'رمز عبور',
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {
              _errorText = null;
            }),
            onSubmitted: (_) => _submit(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AuthColors.hint,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          if (_errorText != null) AuthErrorText(_errorText!),
          const SizedBox(height: 20),
          const AuthBodyText('رمز عبورت رو نداری یا یادت رفته؟'),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CodeRequestScreen()),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: AuthColors.link,
                padding: const EdgeInsets.symmetric(vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              child: const Text('دریافت از ربات بله'),
            ),
          ),
        ],
      ),
    );
  }
}
