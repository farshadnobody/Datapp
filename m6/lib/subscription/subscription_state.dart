import 'package:flutter/foundation.dart';
import '../bootstrap/bootstrap_service.dart';

/// وضعیتِ اشتراکِ کاربر و سهمیه‌ی امروزِ سوپرلایک. منبعِ حقیقت سرورِ
/// (GET /api/subscription)؛ اپ فقط برای نمایشِ قفل/باز و جلوگیری از درخواستِ
/// بی‌فایده ازش استفاده می‌کنه، و هر قفلی دوباره تو سرور چک می‌شه.
class SubscriptionState extends ChangeNotifier {
  SubscriptionState._();
  static final SubscriptionState instance = SubscriptionState._();

  bool loaded = false;
  bool isPremium = false;
  DateTime? expiresAt;
  int superLikesDaily = 0;
  int superLikesLeft = 0;
  bool likesUnlimited = false;
  int likesDaily = 0;
  int likesLeft = 0;
  int freeChatHistory = 0; // فقط برای رایگان‌ها؛ ۰ = نامحدود
  int maxMessageChars = 1000;

  /// تا وقتی وضعیت از سرور نیومده (loaded=false) مانعِ کاربر نمی‌شیم؛ سرور خودش
  /// تصمیم می‌گیره. بعد از اون: فقط اشتراکی‌هایی که سهمیه دارن.
  bool get canSuperLike => !loaded || (isPremium && superLikesLeft > 0);

  /// لایکِ معمولی: اشتراکی‌ها نامحدودن، رایگان‌ها سهمیه‌ی روزانه دارن.
  bool get canLike => !loaded || likesUnlimited || likesLeft > 0;

  /// با «درخواستِ اولیه» (bootstrap) همه‌چیز یکجا تازه می‌شه (اشتراک، سهمیه‌ها، لایک‌ها،
  /// و هر محتوایی که نسخه‌اش عوض شده)، نه فقط اشتراک.
  Future<void> refresh() => BootstrapService.instance.refresh(force: true);

  /// نتیجه‌ی bootstrap (یا هر منبعِ دیگه‌ای) رو اعمال می‌کنه.
  void applyStatus(SubscriptionStatus s) {
    loaded = true;
    isPremium = s.premium;
    expiresAt = s.expiresAt;
    superLikesDaily = s.superLikesDaily;
    superLikesLeft = s.superLikesLeft;
    likesUnlimited = s.likesUnlimited;
    likesDaily = s.likesDaily;
    likesLeft = s.likesLeft;
    freeChatHistory = s.freeChatHistory;
    maxMessageChars = s.maxMessageChars;
    notifyListeners();
  }

  /// بعد از یه سوپرلایکِ موفق (تا refresh بعدی).
  void noteSuperLikeSpent() {
    if (superLikesLeft > 0) {
      superLikesLeft--;
      notifyListeners();
    }
  }

  /// بعد از یه لایکِ موفقِ کاربرِ رایگان (تا refresh بعدی).
  void noteLikeSpent() {
    if (!likesUnlimited && likesLeft > 0) {
      likesLeft--;
      notifyListeners();
    }
  }

  void clear() {
    loaded = false;
    isPremium = false;
    expiresAt = null;
    superLikesDaily = 0;
    superLikesLeft = 0;
    likesUnlimited = false;
    likesDaily = 0;
    likesLeft = 0;
    freeChatHistory = 0;
    maxMessageChars = 1000;
    notifyListeners();
  }
}

class SubscriptionStatus {
  final bool premium;
  final DateTime? expiresAt;
  final int superLikesDaily;
  final int superLikesLeft;
  final bool likesUnlimited;
  final int likesDaily;
  final int likesLeft;
  final int freeChatHistory;
  final int maxMessageChars;
  SubscriptionStatus({
    required this.premium,
    required this.expiresAt,
    required this.superLikesDaily,
    required this.superLikesLeft,
    required this.likesUnlimited,
    required this.likesDaily,
    required this.likesLeft,
    required this.freeChatHistory,
    required this.maxMessageChars,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) => SubscriptionStatus(
        premium: json['premium'] ?? false,
        expiresAt: DateTime.tryParse('${json['expires_at'] ?? ''}'),
        superLikesDaily: json['super_likes_daily'] ?? 0,
        superLikesLeft: json['super_likes_left'] ?? 0,
        likesUnlimited: json['likes_unlimited'] ?? false,
        likesDaily: json['likes_daily'] ?? 0,
        likesLeft: json['likes_left'] ?? 0,
        freeChatHistory: json['free_chat_history'] ?? 0,
        maxMessageChars: json['max_message_chars'] ?? 1000,
      );
}
