class MatchSummary {
  final String publicId;
  final String name;
  final String photoUrl;
  final DateTime? matchedAt;

  MatchSummary({
    required this.publicId,
    required this.name,
    required this.photoUrl,
    this.matchedAt,
  });

  factory MatchSummary.fromJson(Map<String, dynamic> json) => MatchSummary(
        publicId: json['public_id'],
        name: json['name'],
        photoUrl: json['photo_url'] ?? '',
        matchedAt:
            json['matched_at'] != null ? DateTime.tryParse(json['matched_at']) : null,
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
