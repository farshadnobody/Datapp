import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_session.dart';
import 'models/profile_models.dart';
import 'models/match_models.dart';
import 'models/chat_models.dart';

// ============================================================
// IMPORTANT: change this depending on how you're running the app
// ============================================================
// - Android Emulator  -> http://10.0.2.2:8080
// - Real phone (USB/WiFi, same network as your computer)
//                     -> http://<YOUR_COMPUTER_LOCAL_IP>:8080
// - iOS Simulator     -> http://localhost:8080
const String backendBaseUrl = 'http://192.168.1.100:8080';

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
  static Future<http.Response> _post(String path, Map<String, dynamic> body,
      {bool authenticated = false}) async {
    final headers = {'Content-Type': 'application/json'};
    if (authenticated) {
      headers['Authorization'] = 'Bearer ${AuthSession.token}';
    }
    try {
      return await http
          .post(
            Uri.parse('$backendBaseUrl$path'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw NetworkException();
    } on SocketException {
      throw NetworkException();
    } on http.ClientException {
      throw NetworkException();
    }
  }

  static Future<http.Response> _get(String path,
      {bool authenticated = false}) async {
    final headers = <String, String>{};
    if (authenticated) {
      headers['Authorization'] = 'Bearer ${AuthSession.token}';
    }
    try {
      return await http
          .get(Uri.parse('$backendBaseUrl$path'), headers: headers)
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw NetworkException();
    } on SocketException {
      throw NetworkException();
    } on http.ClientException {
      throw NetworkException();
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
      final response = await http
          .get(Uri.parse('$backendBaseUrl/api/health'))
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<ProfileOptions> fetchProfileOptions() async {
    final response = await _get('/api/profile/options');
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
    final response = await _get('/api/profile/me', authenticated: true);
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw ApiException(data['error'] ?? 'unknown_error');
    }
    return MyProfile.fromJson(jsonDecode(response.body));
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
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw ApiException(data['error'] ?? 'unknown_error');
      }
      return data;
    } on TimeoutException {
      throw NetworkException();
    } on SocketException {
      throw NetworkException();
    } on http.ClientException {
      throw NetworkException();
    }
  }

  static Future<http.Response> _getUri(Uri uri, {bool authenticated = false}) async {
    final headers = <String, String>{};
    if (authenticated) {
      headers['Authorization'] = 'Bearer ${AuthSession.token}';
    }
    try {
      return await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw NetworkException();
    } on SocketException {
      throw NetworkException();
    } on http.ClientException {
      throw NetworkException();
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
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (minAge != null) params['min_age'] = '$minAge';
    if (maxAge != null) params['max_age'] = '$maxAge';
    if (maxDistanceKm != null) params['max_distance_km'] = '$maxDistanceKm';
    if (exclude.isNotEmpty) params['exclude'] = exclude.join(',');

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

  static Future<SwipeResult> swipe(String publicId, String direction) async {
    final response = await _post(
        '/api/discovery/swipe', {'public_id': publicId, 'direction': direction},
        authenticated: true);
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw ApiException(data['error'] ?? 'unknown_error');
    }
    return SwipeResult.fromJson(data);
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

  static Future<List<ChatMessage>> fetchMessages(String withPublicId) async {
    final uri = Uri.parse('$backendBaseUrl/api/messages/history')
        .replace(queryParameters: {'with': withPublicId});
    final response = await _getUri(uri, authenticated: true);
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw ApiException(data['error'] ?? 'unknown_error');
    }
    final list = jsonDecode(response.body) as List;
    return list.map((e) => ChatMessage.fromJson(e)).toList();
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
}
