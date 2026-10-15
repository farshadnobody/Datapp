import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../style/app_colors.dart';

// اسم اپ که تو صفحه‌ی اول به‌جای لوگو نشون داده می‌شه — هر وقت لوگو داشتی
// همین‌جا (و تو start_screen.dart) عوضش کن.
const String kAppName = 'Dating App';

// حداقل تعداد رقم برای فعال شدن دکمه‌ی «بعدی» تو صفحه‌های شماره موبایل.
const int kMinPhoneDigits = 10;

/// پالت صفحات ورود — تم تیره‌ی گرم، هماهنگ با پالت سراسری اپ (AppDark).
/// پس‌زمینه هم‌رنگ پس‌زمینه‌ی تیندره (مشکی با ته‌مایه‌ی قهوه‌ای) و باکس‌ها
/// هم‌رنگ کارت‌ها (مثل باکس Sporty در اکسپلور).
class AuthColors {
  /// رنگ برند — صورتیِ سرِ گرادیانت صفحه‌ی شروع (جای قرمز قدیمی).
  static const red = Color(0xFFFD267A);

  /// نارنجیِ تهِ گرادیانت برند.
  static const accentEnd = Color(0xFFFF6036);

  /// پس‌زمینه‌ی صفحه‌های ورود — هم‌رنگ پس‌زمینه‌ی کل اپ.
  static const background = AppDark.bg;

  /// رنگ متن اصلی — سفید گرم.
  static const text = Color(0xFFF7F4F1);

  /// متن‌های توضیحی.
  static const secondaryText = Color(0xFFC9BFB8);

  /// hint فیلدها.
  static const hint = Color(0xFF8D817A);

  /// خطِ دور باکس‌ها.
  static const line = AppDark.border;

  /// پس‌زمینه‌ی دکمه‌ی غیرفعال.
  static const disabledFill = AppDark.cardAlt;

  /// رنگ فیلد ورودی — هم‌رنگ باکس‌های اپ (مثل باکس Sporty).
  static const fieldFill = AppDark.card;

  /// رنگ لینک‌ها — برند جدید.
  static const link = Color(0xFFFD267A);
}

// ارقام فارسی/عربی رو به انگلیسی تبدیل می‌کنم (کیبورد فارسی ۰۹۱۲... می‌نویسه
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

// اسکلت مشترک صفحه‌های ورود: پس‌زمینه‌ی تیره‌ی گرم با یه هاله‌ی خیلی کم‌رنگ
// از گرادیانت برند بالای صفحه، فلش برگشت بالا، محتوای اسکرول‌شونده وسط، و
// دکمه‌ی گرد پایین صفحه (بالای کیبورد می‌مونه).
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
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: AuthColors.background,
          body: DecoratedBox(
            // هاله‌ی خیلی محوِ صورتی بالای صفحه — همون حس‌وحال گرادیانت شروع.
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-1.2, -1.4),
                radius: 1.6,
                colors: [Color(0x33FD267A), Color(0x0012100F)],
                stops: [0.0, 1.0],
              ),
            ),
            child: SafeArea(
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
                              color: AuthColors.text, size: 26),
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
        fontSize: 30,
        fontWeight: FontWeight.w800,
        height: 1.35,
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
        height: 1.7,
        color: AuthColors.secondaryText,
      ),
    );
  }
}

/// ظاهر مشترک همه‌ی فیلدها: باکس گردِ تیره (هم‌رنگ کارت‌های اپ) با حاشیه‌ی
/// نازک؛ موقع فوکوس حاشیه صورتی می‌شه.
Decoration authFieldDecoration({required bool focused, bool error = false}) {
  return BoxDecoration(
    color: AuthColors.fieldFill,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color: error
          ? AuthColors.red
          : focused
              ? AuthColors.red
              : AuthColors.line,
      width: focused || error ? 1.6 : 1.2,
    ),
  );
}

// فیلد ورودی (متن، رمز، شماره): باکس گرد تیره با فیل رنگِ کارت اپ.
// موقع فوکوس حاشیه‌ش گرادیانت‌رنگ (صورتی) می‌شه.
class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool autofocus;
  final Widget? suffixIcon;
  final Widget? prefix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final bool enabled;

  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.autofocus = true,
    this.suffixIcon,
    this.prefix,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return Container(
            decoration: authFieldDecoration(focused: focused),
            child: TextField(
              controller: controller,
              enabled: enabled,
              autofocus: autofocus,
              obscureText: obscureText,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              textInputAction: textInputAction,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              cursorColor: AuthColors.red,
              cursorHeight: 24,
              style: const TextStyle(
                  fontSize: 18,
                  color: AuthColors.text,
                  fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                    fontSize: 16,
                    color: AuthColors.hint,
                    fontWeight: FontWeight.w400),
                prefixIcon: prefix,
                suffixIcon: suffixIcon,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
                border: InputBorder.none,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// فیلد شماره موبایل با کد کشور جدا: باکس ثابتِ «+98» سمت راست (چون
/// بک‌اند فقط شماره‌ی ایران رو ساپورت می‌کنه) و باکس شماره کنارش.
class AuthPhoneField extends StatelessWidget {
  final TextEditingController controller;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;
  final bool enabled;

  const AuthPhoneField({
    super.key,
    required this.controller,
    this.autofocus = true,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction = TextInputAction.next,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: TextDirection.rtl,
      children: [
        // باکس کد کشور — ثابت (فعلاً فقط ایران).
        Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: authFieldDecoration(focused: false),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🇮🇷', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text(
                '+98',
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AuthColors.text,
                ),
              ),
              SizedBox(width: 6),
              Icon(Icons.expand_more,
                  size: 20, color: AuthColors.hint),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 58,
            child: AuthField(
              controller: controller,
              autofocus: autofocus,
              enabled: enabled,
              keyboardType: TextInputType.phone,
              inputFormatters: phoneInputFormatters,
              textInputAction: textInputAction,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              // عدد سمت چپ تایپ بشه و hint هم خوانا بمونه.
              hint: '۹۱۲ ۳۴۵ ۶۷۸۹',
            ),
          ),
        ),
      ],
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.error_outline, size: 18, color: AuthColors.red),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.6,
                color: AuthColors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// دکمه‌ی گرد تمام‌عرض با گرادیانت برند (صورتی ← نارنجی؛ همون گرادیانت
// صفحه‌ی شروع) و یه هاله‌ی نرم. onPressed == null یعنی غیرفعال (تیره).
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
    final active = onPressed != null || loading;
    return SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: active ? AppGrad.diagonal : null,
          color: active ? null : AuthColors.disabledFill,
          borderRadius: BorderRadius.circular(28),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x40FD267A),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            // موقع لودینگ، دکمه ظاهرش فعاله ولی لمسش کاری نمی‌کنه.
            onTap: loading ? () {} : onPressed,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
