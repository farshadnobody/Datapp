/// یه پاپ‌آپ (وسطِ صفحه) یا باکسِ شناورِ پایین که ادمین از پنل تعریف کرده.
class Promo {
  final int id;
  final String kind; // popup | banner
  final String title;
  final String body;
  final String imageUrl;
  final String buttonText;
  final String action; // '' | url:https://... | screen:<name>
  final List<String> screens; // خالی = همه‌ی صفحه‌ها
  final bool closable;
  final String frequency; // always | daily | once

  const Promo({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.buttonText,
    required this.action,
    required this.screens,
    required this.closable,
    required this.frequency,
  });

  bool get isPopup => kind == 'popup';
  bool get isBanner => kind == 'banner';
  bool get hasAction => action.isNotEmpty;
  String? get actionUrl => action.startsWith('url:') ? action.substring(4) : null;
  String? get actionScreen => action.startsWith('screen:') ? action.substring(7) : null;

  bool showsOn(String screen) => screens.isEmpty || screens.contains(screen);

  factory Promo.fromJson(Map<String, dynamic> json) => Promo(
        id: (json['id'] as num?)?.toInt() ?? 0,
        kind: json['kind'] ?? 'popup',
        title: json['title'] ?? '',
        body: json['body'] ?? '',
        imageUrl: json['image_url'] ?? '',
        buttonText: json['button_text'] ?? '',
        action: json['action'] ?? '',
        screens: (json['screens'] as List?)?.map((e) => '$e').toList() ?? const [],
        closable: json['closable'] ?? true,
        frequency: json['frequency'] ?? 'always',
      );
}
