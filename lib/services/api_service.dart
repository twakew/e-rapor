import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Deteksi platform secara otomatis:
  // - Windows/Linux/macOS (desktop): pakai localhost
  // - Android Emulator: pakai 10.0.2.2
  // - Android fisik: ganti dengan IP lokal komputer Anda (e.g. 192.168.1.5)
  // Base URL bisa di-override tanpa edit kode:
  //   flutter run --dart-define=API_BASE_URL=https://contoh.com
  // Produksi wajib HTTPS; default di bawah hanya untuk dev lokal.
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String _getBaseUrl() {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    if (kIsWeb) return 'http://localhost:3000';
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return 'http://localhost:3000';
    }
    // Android/iOS
    // Emulator: 10.0.2.2
    // HP fisik: ganti dengan IP komputer (cari via ipconfig/ifconfig)
    return 'http://192.168.1.31:3000';
  }

  static String get baseUrl => _getBaseUrl();

  late Dio _dio;
  String? _token;

  Future<void> init() async {
    final url = _getBaseUrl();
    debugPrint('[API] Initializing with baseUrl: $url');

    _dio = Dio(
      BaseOptions(
        baseUrl: url,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Load token
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Refresh token from storage setiap request
          final prefs = await SharedPreferences.getInstance();
          final currentToken = prefs.getString('jwt_token');
          if (currentToken != null) {
            options.headers['Authorization'] = 'Bearer $currentToken';
          }
          return handler.next(options);
        },
      ),
    );
  }

  // --- AUTH ---
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );

    if (response.statusCode == 200) {
      _token = response.data['token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', _token!);
      return response.data;
    } else {
      throw Exception('Login gagal');
    }
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  Future<Map<String, dynamic>> register(
    String email,
    String password,
    String fullName,
  ) async {
    final response = await _dio.post(
      '/auth/register',
      data: {'email': email, 'password': password, 'full_name': fullName},
    );
    return response.data;
  }

  Future<void> updatePassword(String newPassword) async {
    await _dio.post('/auth/update-password', data: {'password': newPassword});
  }

  bool get isLoggedIn => _token != null;

  // --- CRUD API ---
  Future<List<dynamic>> getTable(
    String table, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dio.get(
      '/api/$table',
      queryParameters: queryParameters,
    );
    return response.data;
  }

  Future<Map<String, dynamic>> getRow(String table, String id) async {
    final response = await _dio.get('/api/$table/$id');
    return response.data;
  }

  Future<dynamic> insert(String table, dynamic data) async {
    final response = await _dio.post('/api/$table', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> update(
    String table,
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.put('/api/$table/$id', data: data);
    return response.data;
  }

  Future<List<dynamic>> updateBulk(
    String table,
    Map<String, dynamic> where,
    Map<String, dynamic> updates,
  ) async {
    final response = await _dio.put(
      '/api/$table/bulk',
      data: {'where': where, 'updates': updates},
    );
    return response.data;
  }

  Future<void> delete(String table, String id) async {
    await _dio.delete('/api/$table/$id');
  }

  Future<void> deleteBulk(String table, Map<String, dynamic> where) async {
    await _dio.delete('/api/$table/bulk', data: {'where': where});
  }

  /// Get the first row of a table (equivalent to .limit(1).maybeSingle())
  Future<Map<String, dynamic>?> getFirstRow(
    String table, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final params = {...?queryParameters, 'limit': 1};
    final response = await _dio.get('/api/$table', queryParameters: params);
    final data = response.data;
    if (data is List && data.isNotEmpty) {
      return Map<String, dynamic>.from(data.first);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  /// Upsert (insert or update on conflict)
  Future<dynamic> upsert(
    String table,
    List<Map<String, dynamic>> records, {
    String? conflictColumn,
  }) async {
    final response = await _dio.post(
      '/api/$table/upsert',
      data: {
        'records': records,
        if (conflictColumn != null) 'conflict': conflictColumn,
      },
    );
    return response.data;
  }

  /// Update token after login elsewhere
  void setToken(String token) {
    _token = token;
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // --- STORAGE ---
  Future<String> uploadFile(String bucket, File file) async {
    String fileName = file.path.split('/').last;
    FormData formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(file.path, filename: fileName),
    });

    final response = await _dio.post('/storage/upload', data: formData);
    if (response.statusCode == 200) {
      return response.data['url'];
    } else {
      throw Exception('Upload gagal');
    }
  }

  // Untuk menggantikan fungsi RPC Supabase
  Future<dynamic> callRpc(
    String rpcName, {
    Map<String, dynamic>? params,
  }) async {
    try {
      debugPrint('[API] callRpc: $rpcName');
      debugPrint('[API] params: $params');
      debugPrint('[API] URL: $baseUrl/api/rpc/$rpcName');

      final response = await _dio.post('/api/rpc/$rpcName', data: params);

      debugPrint('[API] Response status: ${response.statusCode}');
      debugPrint('[API] Response data: ${response.data}');
      return response.data;
    } catch (e) {
      debugPrint('[API] callRpc error: $e');
      if (e is DioException) {
        debugPrint('[API] Response: ${e.response?.data}');
      }
      rethrow;
    }
  }
}
