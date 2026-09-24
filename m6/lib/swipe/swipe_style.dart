import 'package:flutter/material.dart';

/// جهت متن/چیدمان کل بخش Swipe (کارت‌ها، بنر، نوار پایین).
///
/// بقیه‌ی اپ (اونبوردینگ و ...) راست‌به‌چپه، پس این هم راست‌به‌چپ گذاشته شده.
/// اگه می‌خوای دقیقاً مثل تیندر انگلیسی (چپ‌به‌راست) بشه، فقط همین یه خط رو
/// `TextDirection.ltr` کن.
///
/// نکته: جهت‌های فیزیکی عمداً ثابت موندن — کشیدن به راست = لایک، به چپ = رد،
/// دکمه‌ی ضربدر سمت چپ و قلب سمت راست. فقط متن‌ها و نوار پایین آینه می‌شن.
const TextDirection kSwipeTextDirection = TextDirection.rtl;

/// رنگ‌ها — از روی اسکرین‌شات‌های تیندر نمونه‌برداری شده.
class SwipeColors {
  SwipeColors._();

  static const Color black = Color(0xFF000000);

  /// رنگ ته کارت (زیر دکمه‌ها) که گرادیانت پایین کارت بهش می‌رسه.
  static const Color cardBase = Color(0xFF101113);

  static const Color like = Color(0xFFE9190C);
  static const Color pass = Color(0xFFE9E9EA);
  static const Color superLike = Color(0xFF3D9CF0);
  static const Color superLikeSoft = Color(0xFF9AB9EA);
  static const Color rewind = Color(0xFFFFC629);
  static const Color rewindDisabled = Color(0xFF6E6E72);

  static const Color buttonBg = Color(0xFF262628);
  static const Color buttonBorder = Color(0x1FFFFFFF);

  static const Color pillBg = Color(0xFFF2EEEC);
  static const Color activeGreen = Color(0xFF3AA25C);

  static const Color chipPink = Color(0xFFF4B0EC);
  static const Color chipDark = Color(0x73000000);
  static const Color chipBorder = Color(0x1FFFFFFF);

  static const Color navUnselected = Color(0xFFBDBDBD);
  static const Color badgeRed = Color(0xFFCE130A);
  static const Color bolt = Color(0xFFF4B0EC);

  static const Color bannerTitle = Color(0xFF1C1C1E);
  static const Color bannerSubtitle = Color(0xFF55555A);
  static const Color bannerRing = Color(0xFFF4D1CF);
  static const Color bannerHeart = Color(0xFFCE130C);
}

/// اندازه‌ها (dp) — اسکرین‌شات‌ها روی صفحه‌ی ۷۲۰ پیکسلی (=۳۶۰dp) گرفته شدن.
class SwipeMetrics {
  SwipeMetrics._();

  static const double cardRadius = 28;

  /// ارتفاع ناحیه‌ی بالای کارت (بنر «سلیقه‌ات رو یاد می‌گیریم» یا نوار
  /// For You / nearby) — بدون status bar.
  static const double headerHeight = 58;

  /// ارتفاع نوار پایین اپ (بدونِ safe-area). کارتِ سواپ همین‌قدر از پایینِ
  /// صفحه فاصله داره؛ صفحه‌ی Preview هم برای هم‌اندازه شدنِ کارت ازش استفاده می‌کنه.
  static const double navHeight = 64;

  static const double bigButton = 62;
  static const double smallButton = 46;

  /// فاصله‌ی دکمه‌ها تا لبه‌ی پایین کارت.
  static const double buttonsBottom = 14;

  /// فاصله‌ی متن‌های روی کارت تا لبه‌ی پایین (جا برای دکمه‌ها).
  static const double infoBottom = 92;
  static const double infoSide = 16;
}
