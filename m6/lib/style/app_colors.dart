import 'package:flutter/material.dart';

/// پالت رنگ تیره‌ی مشترک بین صفحه‌ی «پروفایل من» و باتم‌شیت‌های ویرایشش
/// (قد، شغل، تحصیلات، هویت، Basics، Lifestyle، علاقه‌مندی‌ها و ...).
///
/// عمداً جدا از `_OB` تو onboarding_flow.dart نگه داشته شده (اون کلاس
/// private و مخصوص همون فایله) ولی مقدارهاش یکیه تا حس‌وحال کل اپ یکدست
/// بمونه.
class AppDark {
  AppDark._();

  static const bg = Colors.black;
  static const card = Color(0xFF121214);
  static const cardAlt = Color(0xFF1C1C1E);
  static const border = Color(0xFF35353A);
  static const muted = Color(0xFFA6A6AA);
  static const accent = Color(0xFFCD130A);
  static const warning = Color(0xFFE9190C);
  static const chipSelectedBg = Colors.white;
  static const chipSelectedFg = Colors.black;
}
