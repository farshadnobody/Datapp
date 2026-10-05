import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../api_client.dart';
import '../auth_session.dart';

/// یه رویدادِ لحظه‌ای از سرور (message، match، likes_changed، unmatched، chat_cleared،
/// account_changed، config_changed) — یا رویدادِ محلیِ «connected» وقتی اتصال برقرار شد.
class RealtimeEvent {
  final String type;
  final Map<String, dynamic> data;
  const RealtimeEvent(this.type, [this.data = const {}]);
}

/// یه WebSocket برای «کلِ اپ» (نه فقط صفحه‌ی چت). تا وقتی اپ جلوی چشمه وصله و سرور
/// هر اتفاقی (پیام، متچ، لایک، تغییرِ اشتراک و تنظیمات) رو همون لحظه می‌فرسته، پس اپ
/// لازم نیست مرتب بپرسه «چیزی عوض شده؟».
///
/// وقتی اپ می‌ره پس‌زمینه، اتصال بسته می‌شه (باتری) و نوتیفیکیشنِ معمولی (Firebase)
/// کار رو برمی‌داره؛ با برگشتن، دوباره وصل می‌شه.
class RealtimeService with WidgetsBindingObserver {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  final StreamController<RealtimeEvent> _events = StreamController<RealtimeEvent>.broadcast();
  Stream<RealtimeEvent> get events => _events.stream;

  /// آیا الان واقعاً وصلیم؟ (وقتی false باشه، صفحه‌ها برای تازه موندنِ داده به
  /// روشِ قدیمی — رفرش موقعِ ورود — برمی‌گردن.)
  final ValueNotifier<bool> connected = ValueNotifier<bool>(false);

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _retryTimer;
  bool _wanted = false;
  bool _observing = false;
  bool _foreground = true;
  bool _everConnected = false;
  int _attempt = 0;
  int _generation = 0; // برای نادیده گرفتنِ callbackهای یه اتصالِ قدیمی

  /// بعد از لاگین/باز شدنِ اپ صدا زده می‌شه.
  void start() {
    if (AuthSession.token == null) return;
    _wanted = true;
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    if (_channel == null && _foreground) _connect();
  }

  /// موقعِ خروج از حساب.
  void stop() {
    _wanted = false;
    _everConnected = false;
    _teardown();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      if (_wanted && _channel == null) {
        _attempt = 0;
        _connect();
      }
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _foreground = false;
      _teardown(); // پس‌زمینه: نوتیفیکیشنِ Firebase جاش رو می‌گیره
    }
  }

  void _teardown() {
    _generation++;
    _retryTimer?.cancel();
    _retryTimer = null;
    _sub?.cancel();
    _sub = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    if (connected.value) connected.value = false;
  }

  void _connect() {
    final token = AuthSession.token;
    if (!_wanted || token == null) return;
    final gen = ++_generation;
    try {
      final channel = IOWebSocketChannel.connect(
        Uri.parse(ApiClient.webSocketBaseUrl),
        // توکن تو هدر می‌ره (نه آدرس)، تا تو لاگ‌ها نمونه.
        headers: {'Authorization': 'Bearer $token'},
        pingInterval: const Duration(seconds: 50),
        connectTimeout: const Duration(seconds: 12),
      );
      _channel = channel;
      channel.ready.then((_) {
        if (gen != _generation) return;
        _attempt = 0;
        final reconnect = _everConnected;
        _everConnected = true;
        connected.value = true;
        // «connected» برای صفحه‌هاست تا بعد از یه قطعیِ طولانی، چیزی که از دست رفته رو
        // دوباره بگیرن (bootstrap، پیام‌های جدید...).
        _events.add(RealtimeEvent('connected', {'reconnect': reconnect}));
      }).catchError((_) {
        if (gen == _generation) _scheduleRetry();
      });
      _sub = channel.stream.listen(
        (raw) {
          if (gen != _generation) return;
          try {
            final decoded = jsonDecode(raw as String);
            if (decoded is Map<String, dynamic> && decoded['type'] is String) {
              _events.add(RealtimeEvent(decoded['type'] as String, decoded));
            }
          } catch (_) {}
        },
        onError: (_) {
          if (gen == _generation) _scheduleRetry();
        },
        onDone: () {
          if (gen == _generation) _scheduleRetry();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleRetry();
    }
  }

  /// قطع شد: با تأخیرِ فزاینده (۲، ۴، ۸ ... تا ۶۰ ثانیه + کمی تصادفی) دوباره وصل شو. ۲۰۰۰
  /// کاربر بعد از ری‌استارتِ سرور نباید همه تو یه ثانیه وصل بشن.
  void _scheduleRetry() {
    _teardownConnectionOnly();
    if (!_wanted || !_foreground) return;
    _attempt++;
    final base = math.min(60, 1 << math.min(_attempt, 6)); // 2,4,8,...,60
    final jitter = math.Random().nextInt(1500);
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: base, milliseconds: jitter), () {
      _retryTimer = null;
      if (_wanted && _foreground && _channel == null) _connect();
    });
  }

  void _teardownConnectionOnly() {
    _generation++;
    _sub?.cancel();
    _sub = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    if (connected.value) connected.value = false;
  }
}
