import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/chat_models.dart';

/// عکسِ لحظه‌ای از یه گفتگو که روی گوشی ذخیره شده.
class ChatSnapshot {
  final List<ChatMessage> messages;
  final int epoch;
  final bool hasMore;
  final bool locked;
  const ChatSnapshot({
    required this.messages,
    required this.epoch,
    required this.hasMore,
    required this.locked,
  });

  /// آخرین شناسه‌ی واقعیِ سرور (برای «پیام‌های جدیدتر از این»).
  int get lastId {
    var last = 0;
    for (final m in messages) {
      if (m.id > last) last = m.id;
    }
    return last;
  }
}

/// کشِ محلیِ پیام‌ها: هر گفتگو یه فایلِ JSON کوچیک (حداکثر ۲۰۰ پیامِ آخر). چت فوری از
/// روی همین باز می‌شه و از سرور فقط «پیام‌های جدیدتر از آخرین شناسه» خواسته می‌شه
/// (معمولاً صفر پیام، چون پیام‌های لحظه‌ای با WebSocket میان).
class ChatCache {
  ChatCache._();

  static const int _maxMessages = 200;
  static Directory? _dirCache;

  static Future<Directory> _dir() async {
    final cached = _dirCache;
    if (cached != null) return cached;
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}/chat_cache');
    if (!await d.exists()) await d.create(recursive: true);
    return _dirCache = d;
  }

  // public_id فقط حروف/عدد/خط‌تیره/آندرلاین داره؛ ولی برای امنیتِ مسیر باز هم پاک‌سازی می‌شه.
  static String _safe(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  static Future<File> _file(String publicId) async =>
      File('${(await _dir()).path}/${_safe(publicId)}.json');

  static Future<ChatSnapshot?> load(String publicId) async {
    try {
      final f = await _file(publicId);
      if (!await f.exists()) return null;
      final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final list = (data['messages'] as List)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      return ChatSnapshot(
        messages: list,
        epoch: (data['epoch'] as num?)?.toInt() ?? 0,
        hasMore: data['has_more'] ?? false,
        locked: data['locked'] ?? false,
      );
    } catch (_) {
      return null; // فایلِ خراب = کش نداریم
    }
  }

  /// فقط پیام‌های «واقعی» (دارای شناسه‌ی سرور) ذخیره می‌شن؛ پیامِ در حالِ ارسال نه.
  static Future<void> save(
    String publicId,
    List<ChatMessage> messages, {
    required int epoch,
    required bool hasMore,
    required bool locked,
  }) async {
    try {
      var real = messages.where((m) => m.id > 0).toList();
      var truncated = false;
      if (real.length > _maxMessages) {
        real = real.sublist(real.length - _maxMessages);
        truncated = true;
      }
      final f = await _file(publicId);
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode({
        'epoch': epoch,
        'has_more': hasMore || truncated,
        'locked': locked,
        'messages': real.map((m) => m.toJson()).toList(),
      }));
      await tmp.rename(f.path); // اتمیک: نیمه‌نوشته نمی‌مونه
    } catch (_) {}
  }

  static Future<void> clear(String publicId) async {
    try {
      final f = await _file(publicId);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// موقعِ خروج از حساب: پیام‌های خصوصی نباید روی گوشی بمونه.
  static Future<void> clearAll() async {
    try {
      final d = await _dir();
      if (await d.exists()) await d.delete(recursive: true);
      _dirCache = null;
    } catch (_) {}
  }
}
