import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// اسم اپ که تو صفحه‌ی اول به‌جای لوگو نشون داده می‌شه — هر وقت لوگو داشتی
// همین‌جا (و تو start_screen.dart) عوضش کن.
const String kAppName = 'Dating App';

// حداقل تعداد رقم برای فعال شدن دکمه‌ی «بعدی» تو صفحه‌های شماره موبایل.
const int kMinPhoneDigits = 10;

class AuthColors {
  static const red = Color(0xFFCD130A);
  static const background = Color(0xFFF0EEEE);
  static const text = Color(0xFF1C1B1B);
  static const secondaryText = Color(0xFF4A4747);
  static const hint = Color(0xFF9B9594);
  static const line = Color(0xFFB2ABAA);
  static const disabledFill = Color(0xFFD3CFCE);
  static const link = Color(0xFF2872B0);
}

// ارقام فارسی/عربی رو به انگلیسی تبدیل می‌کنه (کیبورد فارسی ۰۹۱۲... می‌نویسه
// ولی بک‌اند 0912... می‌خواد).
String normalizeDigits(String input) {
  final buffer = StringBuffer();
  for (final unit in input.runes) {
    if (unit >= 0x06F0 && unit <= 0x06F9) {
      buffer.writeCharCode(unit - 0x06F0 + 0x30);
    } else if (unit >= 0x0660 && unit <= 0x0669) {
      buffer.writeCharCode(unit - 0x0660 + 0x30);
    } else {
      buffer.writeCharCode(unit);
    }
  }
  return buffer.toString();
}

final List<TextInputFormatter> phoneInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9\u06F0-\u06F9\u0660-\u0669+]')),
  LengthLimitingTextInputFormatter(15),
];

bool isPhoneComplete(String raw) =>
    normalizeDigits(raw).replaceAll('+', '').length >= kMinPhoneDigits;

// اسکلت مشترک صفحه‌های ورود: پس‌زمینه‌ی روشن، فلش برگشت بالا، محتوای
// اسکرول‌شونده وسط، و دکمه‌ی گرد پایین صفحه (بالای کیبورد می‌مونه).
class AuthScaffold extends StatelessWidget {
  final Widget body;
  final Widget? bottom;
  final bool showBack;

  const AuthScaffold({
    super.key,
    required this.body,
    this.bottom,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: AuthColors.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showBack)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        alignment: AlignmentDirectional.centerStart,
                        icon: const Icon(Icons.arrow_back,
                            color: AuthColors.text, size: 28),
                        onPressed: () => Navigator.maybePop(context),
                      ),
                    )
                  else
                    const SizedBox(height: 48),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [body],
                      ),
                    ),
                  ),
                  if (bottom != null) ...[
                    const SizedBox(height: 16),
                    bottom!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthTitle extends StatelessWidget {
  final String text;
  const AuthTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        height: 1.3,
        color: AuthColors.text,
      ),
    );
  }
}

class AuthBodyText extends StatelessWidget {
  final String text;
  const AuthBodyText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        height: 1.6,
        color: AuthColors.secondaryText,
      ),
    );
  }
}

// فیلد ورودی با خط زیرین (مثل تیندر). خط زیرین موقع فوکوس قرمز می‌شه.
class AuthUnderlineField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool autofocus;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final bool enabled;

  const AuthUnderlineField({
    super.key,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.autofocus = true,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      obscureText: obscureText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      cursorColor: AuthColors.text,
      style: const TextStyle(fontSize: 20, color: AuthColors.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 18, color: AuthColors.hint),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AuthColors.line, width: 1.5),
        ),
        disabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AuthColors.line, width: 1.5),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AuthColors.red, width: 2),
        ),
      ),
    );
  }
}

class AuthErrorText extends StatelessWidget {
  final String text;
  const AuthErrorText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: AuthColors.red,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// دکمه‌ی گرد تمام‌عرض. onPressed == null یعنی غیرفعال (خاکستری).
class AuthPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const AuthPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        // موقع لودینگ، دکمه ظاهرش فعاله ولی لمسش کاری نمی‌کنه.
        onPressed: loading ? () {} : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AuthColors.red,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AuthColors.disabledFill,
          disabledForegroundColor: AuthColors.hint,
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}
