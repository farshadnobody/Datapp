class ChatMessage {
  final int id;
  final bool fromMe;
  final String body;
  final DateTime sentAt;
  // پیام لایک‌شده (قلبِ کنار حباب) — از `liked` تو جیسون میاد؛ بک‌اند
  // فعلاً نمی‌فرستدش (پیش‌فرض false)، بعداً اضافه می‌شه.
  final bool liked;

  ChatMessage({
    required this.id,
    required this.fromMe,
    required this.body,
    required this.sentAt,
    this.liked = false,
  });

  ChatMessage copyWith({bool? liked}) => ChatMessage(
        id: id,
        fromMe: fromMe,
        body: body,
        sentAt: sentAt,
        liked: liked ?? this.liked,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'from_me': fromMe,
        'body': body,
        'sent_at': sentAt.toIso8601String(),
        'liked': liked,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] ?? 0,
        fromMe: json['from_me'] ?? false,
        body: json['body'],
        sentAt: DateTime.tryParse(json['sent_at']?.toString() ?? '') ?? DateTime.now(),
        liked: json['liked'] ?? false,
      );
}

/// یه صفحه از پیام‌های مکالمه (قدیمی → جدید).
///  - [hasMore]: پیام‌های قدیمی‌ترِ قابل‌دیدن هم هست (دکمه‌ی «پیام‌های قبلی»).
///  - [locked]: پیام‌های قدیمی‌تری هست که فقط با اشتراک دیده می‌شن (کاربرِ رایگان).
class MessagesPage {
  final List<ChatMessage> messages;
  final bool hasMore;
  final bool locked;

  /// شمارنده‌ی «پاک کردنِ گفتگو» (برای اعتبارِ کشِ محلی).
  final int epoch;

  /// true یعنی «کشِ محلی‌ات بی‌اعتباره؛ این لیست رو جای همه‌ی پیام‌هات بذار».
  final bool reset;

  const MessagesPage({
    required this.messages,
    required this.hasMore,
    required this.locked,
    this.epoch = 0,
    this.reset = false,
  });
}
