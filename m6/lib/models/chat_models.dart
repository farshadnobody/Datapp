class ChatMessage {
  final int id;
  final bool fromMe;
  final String body;
  final DateTime sentAt;

  ChatMessage({
    required this.id,
    required this.fromMe,
    required this.body,
    required this.sentAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] ?? 0,
        fromMe: json['from_me'] ?? false,
        body: json['body'],
        sentAt: DateTime.tryParse(json['sent_at']?.toString() ?? '') ?? DateTime.now(),
      );
}
