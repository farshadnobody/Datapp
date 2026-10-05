import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../api_client.dart';
import '../models/match_models.dart';
import '../realtime/realtime_service.dart';

/// لیستِ چت‌ها روی گوشی. مستقل از صفحه‌ی چت‌ها زنده‌ست:
///  - یه بار موقعِ باز شدنِ اپ از سرور گرفته می‌شه (و تا اون لحظه از فایلِ ذخیره‌شده نشون
///    داده می‌شه)؛
///  - بعدش فقط با «رویدادهای سرور» عوض می‌شه (پیامِ جدید، متچ، آنمتچ، پاک‌شدنِ گفتگو) —
///    اپ مرتب نمی‌پرسه «چیزی عوض شده؟».
class ConversationsStore extends ChangeNotifier {
  ConversationsStore._();
  static final ConversationsStore instance = ConversationsStore._();

  List<ConversationSummary> items = [];
  bool loading = true;
  String? error;

  bool _started = false;
  bool _refreshing = false;
  StreamSubscription? _sub;
  Timer? _saveTimer;

  /// موقعِ باز شدنِ اپ (HomeScreen.initState) صدا زده می‌شه.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _loadCache();
    if (items.isNotEmpty) {
      loading = false;
      notifyListeners();
    }
    _sub = RealtimeService.instance.events.listen(_onEvent);
    await refresh();
  }

  Future<File> _file() async {
    final base = await getApplicationSupportDirectory();
    return File('${base.path}/conversations_cache.json');
  }

  Future<void> _loadCache() async {
    try {
      final f = await _file();
      if (!await f.exists()) return;
      final list = jsonDecode(await f.readAsString()) as List;
      items = list.map((e) => ConversationSummary.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {}
  }

  void _persist() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), () async {
      try {
        final f = await _file();
        final tmp = File('${f.path}.tmp');
        await tmp.writeAsString(jsonEncode(items.map((e) => e.toJson()).toList()));
        await tmp.rename(f.path);
      } catch (_) {}
    });
  }

  /// دریافتِ کاملِ لیست از سرور (cold start، رویدادِ match، برگشتِ اتصال، تلاشِ دوباره).
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      List<ConversationSummary> list;
      try {
        list = await ApiClient.fetchConversations();
      } catch (_) {
        // اگه /api/conversations هنوز نیست، از لیستِ خامِ متچ‌ها (بدونِ پیام/نوبت).
        final raw = await ApiClient.fetchMatches();
        list = raw
            .map((m) => ConversationSummary(
                  publicId: m.publicId,
                  name: m.name,
                  photoUrl: m.photoUrl,
                  matchedAt: m.matchedAt,
                  state: m.state,
                ))
            .toList();
      }
      items = list;
      error = null;
      loading = false;
      _persist();
    } catch (_) {
      loading = false;
      if (items.isEmpty) error = 'دریافت چت‌ها با مشکل مواجه شد.';
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  int _indexOf(String publicId) => items.indexWhere((c) => c.publicId == publicId);

  ConversationSummary _copy(ConversationSummary c,
          {String? body, DateTime? at, bool? fromMe, String? state, bool clearBody = false}) =>
      ConversationSummary(
        publicId: c.publicId,
        name: c.name,
        photoUrl: c.photoUrl,
        verified: c.verified,
        matchedAt: c.matchedAt,
        lastMessageBody: clearBody ? null : (body ?? c.lastMessageBody),
        lastMessageAt: clearBody ? null : (at ?? c.lastMessageAt),
        lastMessageFromMe: fromMe ?? c.lastMessageFromMe,
        recentlyActive: c.recentlyActive,
        state: state ?? c.state,
      );

  void _onEvent(RealtimeEvent e) {
    final data = e.data;
    switch (e.type) {
      case 'connected':
        if (data['reconnect'] == true) refresh(); // وقتی قطع بودیم ممکنه چیزی از دست رفته باشه
        break;
      case 'match':
        refresh(); // متچِ جدید: اسم و عکسش رو لازم داریم (رویدادِ نادر)
        break;
      case 'message':
        final i = _indexOf('${data['from']}');
        if (i < 0) {
          refresh(); // گفتگوی ناشناخته
          break;
        }
        items[i] = _copy(
          items[i],
          body: '${data['body']}',
          at: DateTime.tryParse('${data['sent_at'] ?? ''}') ?? DateTime.now(),
          fromMe: false,
          state: 'active',
        );
        _persist();
        notifyListeners();
        break;
      case 'unmatched':
        final before = items.length;
        items.removeWhere((c) => c.publicId == '${data['from']}');
        if (items.length != before) {
          _persist();
          notifyListeners();
        }
        break;
      case 'chat_cleared':
        final i = _indexOf('${data['from']}');
        if (i >= 0) {
          items[i] = _copy(items[i], clearBody: true);
          _persist();
          notifyListeners();
        }
        break;
    }
  }

  /// پیامی که خودم فرستادم (از صفحه‌ی چت): بدونِ درخواست، لیست به‌روز می‌شه.
  void noteSent(String publicId, String body, DateTime at) {
    final i = _indexOf(publicId);
    if (i < 0) return;
    items[i] = _copy(items[i], body: body, at: at, fromMe: true, state: 'active');
    _persist();
    notifyListeners();
  }

  /// گفتگو رو خودم پاک کردم.
  void noteCleared(String publicId) {
    final i = _indexOf(publicId);
    if (i < 0) return;
    items[i] = _copy(items[i], clearBody: true);
    _persist();
    notifyListeners();
  }

  /// من آنمتچ/بلاک کردم.
  void noteRemoved(String publicId) {
    items.removeWhere((c) => c.publicId == publicId);
    _persist();
    notifyListeners();
  }

  /// خروج از حساب.
  Future<void> clear() async {
    items = [];
    loading = true;
    error = null;
    _started = false;
    await _sub?.cancel();
    _sub = null;
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
    notifyListeners();
  }
}
