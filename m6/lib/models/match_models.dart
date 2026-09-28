class MatchSummary {
  final String publicId;
  final String name;
  final String photoUrl;
  final DateTime? matchedAt;

  /// 'new_match' | 'active' (از بک‌اند).
  final String? state;

  MatchSummary({
    required this.publicId,
    required this.name,
    required this.photoUrl,
    this.matchedAt,
    this.state,
  });

  factory MatchSummary.fromJson(Map<String, dynamic> json) => MatchSummary(
        publicId: json['public_id'],
        name: json['name'],
        photoUrl: json['photo_url'] ?? '',
        matchedAt:
            json['matched_at'] != null ? DateTime.tryParse(json['matched_at']) : null,
        state: json['state'] as String?,
      );
}

class SwipeResult {
  final bool matched;
  final MatchSummary? match;

  SwipeResult({required this.matched, this.match});

  factory SwipeResult.fromJson(Map<String, dynamic> json) => SwipeResult(
        matched: json['matched'] ?? false,
        match: json['match'] != null ? MatchSummary.fromJson(json['match']) : null,
      );
}

/// یه ردیفِ لیستِ چت — معادلِ خودِ متچ + آخرین پیام (اگه پیامی رد و بدل
/// شده). این از یه اندپوینتِ جدید (`GET /api/conversations`) میاد که هنوز
/// تو بک‌اند نیست؛ خودم اضافه‌ش می‌کنم بعداً. فیلدهایی که بک‌اند نفرسته
/// null/false می‌مونن و اپ خراب نمی‌شه (مثلاً verified/recentlyActive تا
/// وقتی پیاده نشدن همیشه false میان).
class ConversationSummary {
  final String publicId;
  final String name;
  final String photoUrl;
  final bool verified;
  final DateTime? matchedAt;
  final String? lastMessageBody;
  final DateTime? lastMessageAt;
  final bool lastMessageFromMe;
  final bool recentlyActive;

  /// منبعِ حقیقت از بک‌اند: 'new_match' (هنوز هیچ پیامی نیست) یا 'active'.
  /// null فقط اگه بک‌اندِ قدیمی نفرستاده باشه؛ اون‌وقت از وجودِ پیام حدس می‌زنیم.
  final String? state;

  ConversationSummary({
    required this.publicId,
    required this.name,
    required this.photoUrl,
    this.verified = false,
    this.matchedAt,
    this.lastMessageBody,
    this.lastMessageAt,
    this.lastMessageFromMe = false,
    this.recentlyActive = false,
    this.state,
  });

  /// «متچ جدید» = state بک‌اند (نه صرفاً نبودنِ پیام تو لیست لوکال).
  bool get isNewMatch => state != null ? state == 'new_match' : !hasMessages;

  bool get hasMessages => lastMessageBody != null && lastMessageBody!.isNotEmpty;

  /// true یعنی طرف پیام داده و منتظر جواب ماست.
  bool get yourTurn => hasMessages && !lastMessageFromMe;

  factory ConversationSummary.fromJson(Map<String, dynamic> json) => ConversationSummary(
        publicId: json['public_id'],
        name: json['name'],
        photoUrl: json['photo_url'] ?? '',
        verified: json['verified'] ?? false,
        matchedAt: json['matched_at'] != null ? DateTime.tryParse(json['matched_at']) : null,
        lastMessageBody: json['last_message_body'] as String?,
        lastMessageAt:
            json['last_message_at'] != null ? DateTime.tryParse(json['last_message_at']) : null,
        lastMessageFromMe: json['last_message_from_me'] ?? false,
        recentlyActive: json['recently_active'] ?? false,
        state: json['state'] as String?,
      );
}

/// خلاصه‌ی «کی لایکم کرده» برای کارت تیزرِ بالای صفحه‌ی چت — از
/// `GET /api/likes/summary` (هنوز پیاده نشده). previewPhotoUrls معمولاً
/// باید محوشده/سانسورشده از سمت بک‌اند بیاد (چون هنوز متچ نشدن).
class LikesSummary {
  final int count;
  final int superLikeCount;
  final List<String> previewPhotoUrls;

  LikesSummary({required this.count, this.superLikeCount = 0, this.previewPhotoUrls = const []});

  factory LikesSummary.fromJson(Map<String, dynamic> json) => LikesSummary(
        count: json['count'] ?? 0,
        superLikeCount: json['super_like_count'] ?? 0,
        previewPhotoUrls: List<String>.from(json['preview_photo_urls'] ?? []),
      );
}
