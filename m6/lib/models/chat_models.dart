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

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] ?? 0,
        fromMe: json['from_me'] ?? false,
        body: json['body'],
        sentAt: DateTime.tryParse(json['sent_at']?.toString() ?? '') ?? DateTime.now(),
        liked: json['liked'] ?? false,
      );
}
