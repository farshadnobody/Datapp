import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_session.dart';
import 'connection_monitor.dart';
import 'http_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/profile_models.dart';
import 'models/match_models.dart';
import 'models/chat_models.dart';
import 'subscription/subscription_state.dart';
import 'promo/promo_models.dart';

// ============================================================
// این مقدار دستی تنظیم نمی‌شه — موقع استارت اپ (قبل از نمایش هر صفحه‌ای)
// توسط NetworkConfig.initialize() (تو network_config.dart) بر اساس پلتفرم
// (وب / امولاتور اندروید / گوشی واقعی) به یکی از سه مقدار ثابت تنظیم می‌شه.
// اگه IP لپ‌تاپت عوض شد، همون فایل رو ویرایش کن — عمداً هیچ تنظیمات کاربری
// برای این تو خود اپ نیست.
// ============================================================
String backendBaseUrl = 'http://10.0.2.2:8080';

// ApiException یعنی سرور جواب داد ولی با یه خطای مشخص (مثلاً پسورد اشتباه).
// این با NetworkException فرق داره — این یکی یعنی "سرور جواب داد ولی نه".
class ApiException implements Exception {
  final String code; // e.g. "invalid_credentials", "invalid_phone"
  ApiException(this.code);
}

// NetworkException یعنی اصلاً نتونستیم به سرور وصل بشیم (سرور خاموشه، آدرس
// اشتباهه، اینترنت قطعه، و...). این نباید با ApiException قاطی بشه، چون پیامی
// که باید به کاربر نشون بدیم کاملاً فرق داره.
class NetworkException implements Exception {}

class RequestCodeResult {
  final String code;
  final String deepLink;
  final DateTime expiresAt;
  RequestCodeResult(
      {required this.code, required this.deepLink, required this.expiresAt});
}

class LoginResult {
  final String token;
  final String username;
  final bool hasProfile;
  LoginResult(
      {required this.token, required this.username, required this.hasProfile});
}

class ApiClient {
  // یه اتصالِ مشترک برای همه‌ی درخواست‌ها (keep-alive): به‌جای ساختنِ یه اتصال
  // (و handshake) برای هر درخواست، اتصال‌ها دوباره استفاده می‌شن.
  static final http.Client _client = http.Client();

  // شکستِ شبکه رو به ConnectionMonitor خبر می‌ده (نوار «قطع» بدون پولینگ).
  static NetworkException _networkDown() {
    ConnectionMonitor.reportFailure();
    return NetworkException();
  }

  // اگه سرور به یه درخواست احراز‌هویت‌شده 401 بده یعنی توکن منقضی/نامعتبره:
  // session پاک می‌شه و کاربر برمی‌گرده به صفحه‌ی شروع (تو main.dart وصل شده).
  static void _handleUnauthorized(int statusCode, bool authenticated) {
    // هر جوابی از سرور یعنی اتصال برقراره.
    ConnectionMonitor.reportSuccess();
    if (authenticated && statusCode == 401) {
      AuthSession.expire();
    }
  }

  static Future<http.Response> _post(String path, Map<String, dynamic> body,
      {bool authenticated = false}) async {
    final headers = {'Content-Type': 'application/json'};
    if (authenticated) {
      headers['Authorization'] = 'Bearer ${AuthSession.token}';
    }
    try {
      final response = await _client
          .post(
            Uri.parse('$backendBaseUrl$path'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      _handleUnauthorized(response.statusCode, authenticated);
      return response;
    } on TimeoutException {
      throw _networkDown();
    } on SocketException {
      throw _networkDown();
    } on http.ClientException {
      throw _networkDown();
    }
  }

  static Future<http.Response> _get(String path,
      {bool authenticated = false}) async {
    final headers = <String, String>{};
    if (authenticated) {
      headers['Authorization'] = 'Bearer ${AuthSession.token}';
    }
    try {
      final response = await _client
          .get(Uri.parse('$backendBaseUrl$path'), headers: headers)
          .timeout(const Duration(seconds: 10));
      _handleUnauthorized(response.statusCode, authenticated);
      return response;
    } on TimeoutException {
      throw _networkDown();
    } on SocketException {
      throw _networkDown();
    } on http.ClientException {
      throw _networkDown();
    }
  }

  static Future<RequestCodeResult> requestCode(String phone) async {
    final response = await _post('/api/auth/request-code', {'phone': phone});

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw ApiException(data['error'] ?? 'unknown_error');
    }

    return RequestCodeResult(
      code: data['code'],
      deepLink: data['deep_link'],
      expiresAt: DateTime.parse(data['expires_at']),
    );
  }

  static Future<LoginResult> login(String phone, String password) async {
    final response =
        await _post('/api/auth/login', {'phone': phone, 'password': password});

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw ApiException(data['error'] ?? 'unknown_error');
    }

    return LoginResult(
      token: data['token'],
      username: data['username'],
      hasProfile: data['has_profile'] ?? false,
    );
  }

  // checkHealth برای کادر وضعیت اتصال بالای صفحه استفاده می‌شه — فقط می‌خواد
  // بدونه سرور جواب می‌ده یا نه، به جزئیات پاسخ کاری نداره.
  static Future<bool> checkHealth() async {
    try {
      final response = await _client
          .get(Uri.parse('$backendBaseUrl/api/health'))
          .timeout(const Duration(seconds: 4));
      final ok = response.statusCode == 200;
      if (ok) {
        ConnectionMonitor.reportSuccess();
      } else {
        ConnectionMonitor.reportFailure();
      }
      return ok;
    } catch (_) {
      ConnectionMonitor.reportFailure();
      return false;
    }
  }

  // GET شرطی با کش: جواب (و ETagش) روی گوشی ذخیره می‌شه و دفعه‌ی بعد با
  // If-None-Match پرسیده می‌شه؛ اگه چیزی عوض نشده باشه سرور فقط 304 می‌ده (بدون
  // بدنه). اگه [skipNetworkWithin] داده بشه و کش تازه‌تر از اون باشه، اصلاً
  // درخواستی نمی‌ره. اگه شبکه قطع باشه و کش داشته باشیم، همون کش برمی‌گرده.
  static Future<http.Response> _getCached(
    String path, {
    required String cacheKey,
    bool authenticated = false,
    Duration? skipNetworkWithin,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final base = '${HttpCacheStore.prefix}$cacheKey';
    final cachedBody = prefs.getString('$base:body');
    final cachedEtag = prefs.getString('$base:etag');
    final cachedAt = prefs.getInt('$base:at');

    http.Response fromCache() => http.Response.bytes(
          utf8.encode(cachedBody!),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );

    if (cachedBody != null &&
        skipNetworkWithin != null &&
        cachedAt != null &&
        DateTime.now().millisecondsSinceEpoch - cachedAt <
            skipNetworkWithin.inMilliseconds) {
      return fromCache();
    }

    final headers = <String, String>{};
    if (authenticated) headers['Authorization'] = 'Bearer ${AuthSession.token}';
    if (cachedBody != null && cachedEtag != null) {
      headers['If-None-Match'] = cachedEtag;
    }

    try {
      final response = await _client
          .get(Uri.parse('$backendBaseUrl$path'), headers: headers)
          .timeout(const Duration(seconds: 10));
      _handleUnauthorized(response.statusCode, authenticated);

      if (response.statusCode == 304 && cachedBody != null) {
        await prefs.setInt('$base:at', DateTime.now().millisecondsSinceEpoch);
        return fromCache();
      }
      if (response.statusCode == 200) {
        final body = utf8.decode(response.bodyBytes);
        final etag = response.headers['etag'];
        await prefs.setString('$base:body', body);
        if (etag != null) {
          await prefs.setString('$base:etag', etag);
        } else {
          await prefs.remove('$base:etag');
        }
        await prefs.setInt('$base:at', DateTime.now().millisecondsSinceEpoch);
        return http.Response.bytes(
          response.bodyBytes,
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return response;
    } on TimeoutException {
      if (cachedBody != null) {
        ConnectionMonitor.reportFailure();
        return fromCache();
      }
      throw _networkDown();
    } on SocketException {
      if (cachedBody != null) {
        ConnectionMonitor.reportFailure();
        return fromCache();
      }
      throw _networkDown();
    } on http.ClientException {
      if (cachedBody != null) {
        ConnectionMonitor.reportFailure();
        return fromCache();
      }
      throw _networkDown();
    }
  }

  static Future<ProfileOptions> fetchProfileOptions() async {
    // اول نسخه‌ای که bootstrap ذخیره کرده (و سرور تضمین می‌کنه تازه‌ست)؛ هیچ درخواستی
    // نمی‌ره. فقط اگه هنوز چیزی ذخیره نشده، مستقیم از سرور (با ETag) می‌گیره.
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('bs_options_json');
      if (cached != null) return ProfileOptions.fromJson(jsonDecode(cached));
    } catch (_) {}
    final response =
        await _getCached('/api/profile/options', cacheKey: 'options');
    if (response.statusCode != 200) {
      throw ApiException('unknown_error');
    }
    return ProfileOptions.fromJson(jsonDecode(response.body));
  }

  static Future<void> saveProfile(ProfileInput input) async {
    final response =
        await _post('/api/profile', input.toJson(), authenticated: true);
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw ApiException(data['error'] ?? 'unknown_error');
    }
  }

  static Future<MyProfile> fetchMyProfile() async {
    // پروفایلِ خودت: هر بار با ETag پرسیده می‌شه (تغییرِ گوشیِ دیگه هم دیده
    // می‌شه) ولی وقتی عوض نشده فقط یه 304 خالی جابه‌جا می‌شه.
    final response = await _getCached('/api/profile/me',
        cacheKey: 'me:${AuthSession.phone}', authenticated: true);
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw ApiException(data['error'] ?? 'unknown_error');
    }
    return MyProfile.fromJson(jsonDecode(response.body));
  }

  static Future<void> updateInterestedIn(String interestedIn) async {
    final response = await _post(
        '/api/profile/interested-in', {'interested_in': interestedIn},
        authenticated: true);
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw ApiException(data['error'] ?? 'unknown_error');
    }
  }

  static Future<void> registerPushToken(String token) async {
    final response =
        await _post('/api/push/register', {'token': token}, authenticated: true);
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw ApiException(data['error'] ?? 'unknown_error');
    }
  }

  static Future<Photo> uploadPhoto(List<int> bytes, String filename) async {
    final data = await _uploadFile('/api/profile/photos', bytes, filename);
    return Photo.fromJson(data);
  }

  static Future<void> deletePhoto(String id) async {
    final response = await _post('/api/profile/photos/delete', {'id': id},
        authenticated: true);
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw ApiException(data['error'] ?? 'unknown_error');
    }
  }

  static Future<List<Photo>> reorderPhotos(List<String> order) async {
    final response = await _post('/api/profile/photos/reorder', {'order': order},
        authenticated: true);
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw ApiException(data['error'] ?? 'unknown_error');
    }
    final list = jsonDecode(response.body) as List;
    return list.map((e) => Photo.fromJson(e)).toList();
  }

  // --- عکس‌های خصوصی — کاملاً جدا از متدهای بالا ---

  static Future<PrivatePhoto> uploadPrivatePhoto(
      List<int> bytes, String filename) async {
    final data = await _uploadFile('/api/private-photos', bytes, filename);
    return PrivatePhoto.fromJson(data);
  }

  static Future<List<PrivatePhoto>> fetchPrivatePhotos() async {
    final response = await _get('/api/private-photos/list', authenticated: true);
    if (response.statusCode != 200) {
      throw ApiException('unknown_error');
    }
    final list = jsonDecode(response.body) as List;
    return list.map((e) => PrivatePhoto.fromJson(e)).toList();
  }

  static Future<void> deletePrivatePhoto(String id) async {
    final response = await _post('/api/private-photos/delete', {'id': id},
        authenticated: true);
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw ApiException(data['error'] ?? 'unknown_error');
    }
  }

  // برای Image.network لازمه (چون عکس خصوصی پشت احراز هویته، نه یه لینک باز).
  static Map<String, String> authHeaders() =>
      {'Authorization': 'Bearer ${AuthSession.token}'};

  static Future<Map<String, dynamic>> _uploadFile(
      String path, List<int> bytes, String filename) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$backendBaseUrl$path'));
    request.headers['Authorization'] = 'Bearer ${AuthSession.token}';
    request.files
        .add(http.MultipartFile.fromBytes('photo', bytes, filename: filename));

    try {
      final streamed = await _client.send(request).timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      _handleUnauthorized(response.statusCode, true);
      final data = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw ApiException(data['error'] ?? 'unknown_error');
      }
      return data;
    } on TimeoutException {
      throw _networkDown();
    } on SocketException {
      throw _networkDown();
    } on http.ClientException {
      throw _networkDown();
    }
  }

  static Future<http.Response> _getUri(Uri uri, {bool authenticated = false}) async {
    final headers = <String, String>{};
    if (authenticated) {
      headers['Authorization'] = 'Bearer ${AuthSession.token}';
    }
    try {
      final response =
          await _client.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      _handleUnauthorized(response.statusCode, authenticated);
      return response;
    } on TimeoutException {
      throw _networkDown();
    } on SocketException {
      throw _networkDown();
    } on http.ClientException {
      throw _networkDown();
    }
  }

  static Future<void> updateLocation(double latitude, double longitude) async {
    final response = await _post(
        '/api/profile/location', {'latitude': latitude, 'longitude': longitude},
        authenticated: true);
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw ApiException(data['error'] ?? 'unknown_error');
    }
  }

  static Future<List<DiscoveryCandidate>> fetchDiscovery({
    int? minAge,
    int? maxAge,
    double? maxDistanceKm,
    int limit = 20,
    List<String> exclude = const [],
    bool includeSwiped = false,
    bool lean = false, // کارتِ سبک (سواپ و اکسپلور)؛ جزئیات با زدنِ فلشِ کارت
    String? exploreId, // فقط وقتی یه دسته‌ی اکسپلور واقعاً باز شده؛ فیلترش سمتِ سرور اعمال می‌شه
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (lean) params['lean'] = '1';
    if (exploreId != null && exploreId.isNotEmpty) params['explore_id'] = exploreId;
    if (minAge != null) params['min_age'] = '$minAge';
    if (maxAge != null) params['max_age'] = '$maxAge';
    if (maxDistanceKm != null) params['max_distance_km'] = '$maxDistanceKm';
    if (exclude.isNotEmpty) params['exclude'] = exclude.join(',');
    if (includeSwiped) params['mode'] = 'all';

    final uri =
        Uri.parse('$backendBaseUrl/api/discovery').replace(queryParameters: params);
    final response = await _getUri(uri, authenticated: true);
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw ApiException(data['error'] ?? 'unknown_error');
    }
    final list = jsonDecode(response.body) as List;
    return list.map((e) => DiscoveryCandidate.fromJson(e)).toList();
  }

  static Future<void> removeLike(String publicId) async {
    final response = await _post('/api/matches/remove-like', {'public_id': publicId},
        authenticated: true);
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw ApiException(data['error'] ?? 'unknown_error');
    }
  }

  static Future<DiscoveryCandidate> fetchDiscoveryProfile(String publicId) async {
    final uri = Uri.parse('$backendBaseUrl/api/discovery/profile')
        .replace(queryParameters: {'id': publicId});
    final response = await _getUri(uri, authenticated: true);
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw ApiException(data['error'] ?? 'unknown_error');
    }
    return DiscoveryCandidate.fromJson(jsonDecode(response.body));
  }

  static Future<SwipeResult> swipe(String publicId, String direction,
      {List<String> pendingPasses = const []}) async {
    final response = await _post(
        '/api/discovery/swipe',
        {
          'public_id': publicId,
          'direction': direction,
          // ردهای جمع‌شده همراهِ همین درخواست می‌رن (به‌جای یه درخواستِ جدا)
          if (pendingPasses.isNotEmpty) 'pending_passes': pendingPasses,
        },
        authenticated: true);
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw ApiException(data['error'] ?? 'unknown_error');
    }
    return SwipeResult.fromJson(data);
  }

  /// POST /api/discovery/swipes/batch — چندتا «رد» یکجا (حداکثر ۱۰۰).
  static Future<void> swipeBatch(List<String> publicIds) async {
    final response = await _post(
        '/api/discovery/swipes/batch',
        {
          'swipes': [for (final id in publicIds) {'public_id': id, 'direction': 'pass'}],
        },
        authenticated: true);
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw ApiException(data['error'] ?? 'unknown_error');
    }
  }

  /// POST /api/discovery/rewind {public_id}
  /// آخرین swipeِ قابل‌برگشت رو تو بک‌اند برمی‌گردونه (فقط به‌ترتیبِ معکوسِ
  /// زمانی). public_id باید همون کسی باشه که سرِ استکِ حافظه‌ی session‌ه؛
  /// در غیر این‌صورت بک‌اند 409 `rewind_not_latest` می‌ده. جواب: وضعیتِ
  /// برگشته‌شده (`null` یعنی قبلش هیچ تعاملی نبوده).
  static Future<String?> rewind(String publicId) async {
    final response =
        await _post('/api/discovery/rewind', {'public_id': publicId}, authenticated: true);
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw ApiException(data['error'] ?? 'unknown_error');
    }
    return data['restored_direction'] as String?;
  }

  static Future<List<MatchSummary>> fetchMatches() async {
    final response = await _get('/api/matches', authenticated: true);
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw ApiException(data['error'] ?? 'unknown_error');
    }
    final list = jsonDecode(response.body) as List;
    return list.map((e) => MatchSummary.fromJson(e)).toList();
  }

  // ------------------------------------------------------------------
  // صفحه‌ی چت (لیست مکالمه‌ها) — اندپوینت‌های زیر هنوز تو بک‌اند نیستن؛
  // فرانت کامل بر همین قرارداد ساخته شده، فقط باید بعداً پیاده بشن.
  // ------------------------------------------------------------------

  /// GET /api/conversations
  /// جواب: لیستی از متچ‌ها به‌همراه آخرین پیام (اگه پیامی رد و بدل شده).
  /// شکل هر آیتم دقیقاً همون فیلدهای ConversationSummary.fromJson.
  static Future<List<ConversationSummary>> fetchConversations() async {
    final response = await _get('/api/conversations', authenticated: true);
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw ApiException(data['error'] ?? 'unknown_error');
    }
    final list = jsonDecode(response.body) as List;
    return list.map((e) => ConversationSummary.fromJson(e)).toList();
  }

  /// GET /api/likes/summary
  /// جواب: {"count": N, "preview_photo_urls": [...]} — عکس‌های پیش‌نمایش
  /// باید از سمت بک‌اند محوشده/سانسورشده بیان (چون هنوز متچ نشدن).
  /// GET /api/subscription — وضعیتِ اشتراک و سهمیه‌ی امروزِ سوپرلایک.
  static Future<SubscriptionStatus> fetchSubscription() async {
    final response = await _get('/api/subscription', authenticated: true);
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw ApiException(data['error'] ?? 'unknown_error');
    }
    return SubscriptionStatus.fromJson(jsonDecode(response.body));
  }

  /// GET /api/promos — پاپ‌آپ‌ها و باکس‌های شناورِ فعال (با ETag؛ اگه عوض نشده
  /// فقط یه 304 خالی).
  /// GET /api/likes/ids?limit=30&cursor=... (فقط اشتراکی‌ها) — صفحه‌ی سی‌تاییِ شناسه + version.
  /// جواب: {items:[{public_id,version,is_super_like,liked_at}], next_cursor, count, super_like_count}
  static Future<Map<String, dynamic>> fetchLikesIds({String? cursor, int limit = 30}) async {
    final uri = Uri.parse('$backendBaseUrl/api/likes/ids').replace(queryParameters: {
      'limit': '$limit',
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    });
    final response = await _getUri(uri, authenticated: true);
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw ApiException((data is Map ? data['error'] : null) ?? 'unknown_error');
    }
    return data as Map<String, dynamic>;
  }

  /// POST /api/likes/cards {ids:[..≤50]} (فقط اشتراکی‌ها) — کارتِ سبک با version.
  static Future<List<DiscoveryCandidate>> fetchLikesCards(List<String> ids) async {
    final response = await _post('/api/likes/cards', {'ids': ids}, authenticated: true);
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw ApiException((data is Map ? data['error'] : null) ?? 'unknown_error');
    }
    return (data as List).map((e) => DiscoveryCandidate.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /api/likes/sync — دیگه توسط کلاینتِ جدید صدا زده نمی‌شه (سمتِ سرور برای
  /// سازگاری باقی مونده).
  static Future<Map<String, dynamic>> syncLikes({required List<String> have}) async {
    final response = await _post('/api/likes/sync', {'have': have}, authenticated: true);
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw ApiException((data is Map ? data['error'] : null) ?? 'unknown_error');
    }
    return data as Map<String, dynamic>;
  }

  /// GET /api/bootstrap — «درخواستِ اولیه»: اشتراک + سهمیه‌ها + تعدادِ لایک‌ها + نسخه‌ها؛
  /// تبلیغ‌ها/پلن‌ها/گزینه‌ها فقط وقتی میان که نسخه‌شون با نسخه‌ی اپ فرق داشته باشه.
  static Future<Map<String, dynamic>> bootstrap({
    String? promosVersion,
    String? plansVersion,
    String? optionsVersion,
    bool likesCounts = false,
  }) async {
    final uri = Uri.parse('$backendBaseUrl/api/bootstrap').replace(queryParameters: {
      if (likesCounts) 'lc': '1',
      if (promosVersion != null) 'pv': promosVersion,
      if (plansVersion != null) 'plv': plansVersion,
      if (optionsVersion != null) 'ov': optionsVersion,
    });
    final response = await _getUri(uri, authenticated: true);
    if (response.statusCode != 200) {
      throw ApiException('bootstrap_unavailable');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<List<Promo>> fetchPromos() async {
    final response = await _getCached('/api/promos',
        cacheKey: 'promos:${AuthSession.phone}', authenticated: true);
    if (response.statusCode != 200) {
      throw ApiException('promos_unavailable');
    }
    final list = jsonDecode(response.body) as List;
    return list.map((e) => Promo.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<LikesSummary> fetchLikesSummary() async {
    final response = await _get('/api/likes/summary', authenticated: true);
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw ApiException(data['error'] ?? 'unknown_error');
    }
    return LikesSummary.fromJson(jsonDecode(response.body));
  }

  /// GET /api/likes/list
  /// جواب: آرایه‌ای از پروفایلِ کامل + is_super_like/liked_at — برای گریدِ
  /// صفحه‌ی «لایک‌ها» (نه فقط شمارش خام مثل fetchLikesSummary).
  static Future<List<Map<String, dynamic>>> fetchLikesList() async {
    final response = await _get('/api/likes/list', authenticated: true);
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw ApiException(data['error'] ?? 'unknown_error');
    }
    final list = jsonDecode(response.body) as List;
    return list.cast<Map<String, dynamic>>();
  }

  /// POST /api/matches/unmatch  {public_id}
  static Future<void> unmatch(String publicId) async {
    final response =
        await _post('/api/matches/unmatch', {'public_id': publicId}, authenticated: true);
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw ApiException(data['error'] ?? 'unknown_error');
    }
  }

  /// POST /api/matches/block  {public_id}
  static Future<void> blockUser(String publicId) async {
    final response =
        await _post('/api/matches/block', {'public_id': publicId}, authenticated: true);
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw ApiException(data['error'] ?? 'unknown_error');
    }
  }

  /// POST /api/matches/report  {public_id, reason, details?}
  static Future<void> reportUser(String publicId, {required String reason, String? details}) async {
    final response = await _post(
        '/api/matches/report',
        {
          'public_id': publicId,
          'reason': reason,
          if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
        },
        authenticated: true);
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw ApiException(data['error'] ?? 'unknown_error');
    }
  }

  /// POST /api/matches/feedback  {public_id, feedback}
  static Future<void> sendMatchFeedback(String publicId, String feedback) async {
    final response = await _post(
        '/api/matches/feedback', {'public_id': publicId, 'feedback': feedback},
        authenticated: true);
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw ApiException(data['error'] ?? 'unknown_error');
    }
  }

  /// POST /api/messages/like  {id, liked}
  static Future<void> toggleMessageLike(int messageId, bool liked) async {
    final response = await _post(
        '/api/messages/like', {'id': messageId, 'liked': liked},
        authenticated: true);
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw ApiException(data['error'] ?? 'unknown_error');
    }
  }

  /// GET /api/messages/history?with=<id>[&before=<id>][&after=<id>&epoch=<n>]
  /// صفحه‌های ۵۰تایی؛ کاربرِ رایگان فقط ۵۰ پیامِ آخر رو می‌گیره (بقیه locked).
  ///  - before: پیام‌های قدیمی‌تر از این شناسه (صفحه‌ی قبلی)
  ///  - after + epoch: فقط پیام‌های «جدیدتر» از آخرینِ کشِ گوشی (اگه گفتگو پاک شده
  ///    باشه، سرور reset=true برمی‌گردونه)
  static Future<MessagesPage> fetchMessages(String withPublicId,
      {int? before, int? after, int? epoch}) async {
    final uri = Uri.parse('$backendBaseUrl/api/messages/history').replace(queryParameters: {
      'with': withPublicId,
      if (before != null && before > 0) 'before': '$before',
      if (after != null && after > 0) 'after': '$after',
      if (after != null && after > 0 && epoch != null) 'epoch': '$epoch',
    });
    final response = await _getUri(uri, authenticated: true);
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw ApiException(data['error'] ?? 'unknown_error');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (data['messages'] as List?) ?? const [];
    return MessagesPage(
      messages: list.map((e) => ChatMessage.fromJson(e)).toList(),
      hasMore: data['has_more'] ?? false,
      locked: data['locked'] ?? false,
      epoch: (data['epoch'] as num?)?.toInt() ?? 0,
      reset: data['reset'] ?? false,
    );
  }

  /// POST /api/messages/clear  {public_id} — پیام‌های مکالمه برای هر دو طرف پنهان می‌شه.
  static Future<void> clearConversation(String publicId) async {
    final response =
        await _post('/api/messages/clear', {'public_id': publicId}, authenticated: true);
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw ApiException(data['error'] ?? 'unknown_error');
    }
  }

  static Future<ChatMessage> sendMessage(String toPublicId, String body) async {
    final response = await _post('/api/messages', {'to': toPublicId, 'body': body},
        authenticated: true);
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw ApiException(data['error'] ?? 'unknown_error');
    }
    return ChatMessage.fromJson(data);
  }

  // آدرس WebSocket رو از روی همون backendBaseUrl می‌سازه (http -> ws، https -> wss)
  // و توکن لاگین رو به‌عنوان query param اضافه می‌کنه — چون هندشیک اولیه‌ی
  // WebSocket نمی‌تونه هدر Authorization معمولی داشته باشه.
  static String get webSocketUrl {
    final wsBase = backendBaseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    return '$wsBase/ws?token=${AuthSession.token}';
  }

  /// آدرسِ WebSocket بدونِ توکن (توکن تو هدرِ Authorization می‌ره).
  static String get webSocketBaseUrl {
    final wsBase = backendBaseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    return '$wsBase/ws';
  }
}
