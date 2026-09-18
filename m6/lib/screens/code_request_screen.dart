import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api_client.dart';
import 'auth_ui.dart';

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

  bool get _canSubmit => isPhoneComplete(_phoneController.text);

  Future<void> _submit() async {
    if (!_canSubmit || _loading) return;
    HapticFeedback.lightImpact();
    setState(() {
      _loading = true;
      _errorText = null;
      _result = null;
    });

    try {
      final result = await ApiClient.requestCode(
          normalizeDigits(_phoneController.text.trim()));
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
    final hasResult = _result != null;
    return AuthScaffold(
      bottom: hasResult
          ? AuthPillButton(label: 'باز کردن ربات بله', onPressed: _openBaleBot)
          : AuthPillButton(
              label: 'دریافت کد',
              loading: _loading,
              onPressed: _canSubmit ? _submit : null,
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthTitle(hasResult ? 'کدت آماده‌ست' : 'ثبت‌نام یا فراموشی رمز'),
          const SizedBox(height: 24),
          AuthUnderlineField(
            controller: _phoneController,
            hint: 'شماره موبایل',
            enabled: !hasResult,
            keyboardType: TextInputType.phone,
            inputFormatters: phoneInputFormatters,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {
              _errorText = null;
            }),
            onSubmitted: (_) => _submit(),
          ),
          if (_errorText != null) AuthErrorText(_errorText!),
          const SizedBox(height: 20),
          if (!hasResult)
            const AuthBodyText(
              'شماره‌ات رو وارد کن تا یه کد برات بسازیم. کد رو تو ربات بله می‌فرستی و نام کاربری و رمز عبورت رو می‌گیری.',
            )
          else
            _buildResult(_result!),
        ],
      ),
    );
  }

  Widget _buildResult(RequestCodeResult result) {
    // این متن، چه شماره از قبل ثبت‌نام کرده باشه چه نه، دقیقاً همینه — عمداً
    // یکسانه تا کسی نتونه از این صفحه بفهمه چه شماره‌هایی تو سایت ثبت‌نام کردن.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AuthBodyText('کد زیر برات آماده شد. اعتبار: ۱۵ دقیقه.'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SelectableText(
            result.code,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
              color: AuthColors.text,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const AuthBodyText(
          'یا این کد رو دستی برای ربات @TrustVerifyBot در بله بفرست تا نام کاربری و رمز عبورت رو دریافت کنی.',
        ),
      ],
    );
  }
}
