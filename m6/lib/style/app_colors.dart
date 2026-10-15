import 'package:flutter/material.dart';

/// پالت رنگ سراسری اپ — از روی اسکرین‌شات تیندر نمونه‌گیری شده:
/// پس‌زمینه مشکی خالص نیست و ته‌مایه‌ی قهوه‌ای/گرم داره، کارت‌ها یه پله
/// روشن‌تر و باز گرم هستن، و رنگ برند جای قرمز قبلی، گرادیانت صورتی←نارنجیِ
/// صفحه‌ی شروع اپه (FD267A ← FF6036).
///
/// کدها با نمونه‌گیری پیکسلی از اسکرین‌شات به‌دست اومدن:
///   پس‌زمینه‌ی صفحه: #12110F
///   کارت‌ها (مثل باکس Sporty در Explore): #24201F
///   گرادیانت برند: #FD267A (بالا) ← #FF6036 (پایین)
class AppDark {
  AppDark._();

  /// پس‌زمینه‌ی صفحه‌ها — مشکی با ته‌مایه‌ی قهوه‌ای گرم.
  static const bg = Color(0xFF12110F);

  /// رنگ باکس‌ها و کارت‌ها (هم‌رنگ باکس Sporty).
  static const card = Color(0xFF24201F);

  /// پله‌ی روشن‌ترِ کارت، برای باکس‌های تو در تو و دکمه‌های ثانویه.
  static const cardAlt = Color(0xFF2D2826);

  /// حاشیه‌ی کارت‌ها و خط‌های جداکننده.
  static const border = Color(0xFF3B3531);

  /// متن‌های کم‌اهمیت و hintها — خاکستری گرم.
  static const muted = Color(0xFFB0A7A0);

  /// رنگ برند (صورتیِ سرِ گرادیانت صفحه‌ی شروع). جای قرمز قدیمی.
  static const accent = Color(0xFFFD267A);

  /// سرِ دیگر گرادیانت برند (نارنجیِ تهِ صفحه‌ی شروع).
  static const accentEnd = Color(0xFFFF6036);

  /// خطا و حالت‌های خطرناک — از خانواده‌ی برند، نه قرمز قدیمی.
  static const warning = Color(0xFFFD267A);

  static const chipSelectedBg = Colors.white;
  static const chipSelectedFg = Colors.black;
}

/// گرادیانت برند اپ — همون گرادیانت صفحه‌ی شروع (بالا صورتی، پایین نارنجی).
/// هرجا جای قرمز قبلی گرادیانت می‌خواد (دکمه‌ها، نوار پیشرفت، بج‌ها) از این
/// استفاده کن.
class AppGrad {
  AppGrad._();

  static const top = Color(0xFFFD267A);
  static const bottom = Color(0xFFFF6036);

  /// گرادیانت عمودی استاندارد برند.
  static const vertical = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [top, bottom],
  );

  /// گرادیانت مورب (چپ‌بالا ← راست‌پایین) — برای دکمه‌های افقی بهتره.
  static const diagonal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [top, bottom],
  );
}
