import 'dart:io';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';
import '../models/absensi_model.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Dio? _dio;

  Future<Dio> _getDio() async {
    final baseUrl = await ApiConfig.getBaseUrl();
    if (_dio == null || _dio!.options.baseUrl != baseUrl) {
      _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
        ),
      );

      _dio!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            final token = await ApiConfig.getToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            return handler.next(options);
          },
          onError: (DioException e, handler) {
            return handler.next(e);
          },
        ),
      );
    }
    return _dio!;
  }

  void resetClient() {
    _dio = null;
  }

  String _parseErrorMessage(dynamic error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'Koneksi ke server timeout. Pastikan HP dan laptop berada di satu Wi-Fi.';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'Gagal terhubung ke server. Periksa URL server dan pastikan backend aktif.';
      }
      if (error.response != null && error.response?.data != null) {
        final data = error.response!.data;
        if (data is Map && data.containsKey('detail')) {
          final detail = data['detail'];
          if (detail is String) return detail;
          if (detail is List && detail.isNotEmpty) {
            final first = detail[0];
            if (first is Map && first.containsKey('msg')) {
              return first['msg'].toString();
            }
            return detail.toString();
          }
          return detail.toString();
        }
      }
      return error.message ?? 'Terjadi kesalahan jaringan (${error.response?.statusCode})';
    }
    return error.toString();
  }

  // 1. LOGIN (application/x-www-form-urlencoded OAuth2)
  Future<UserModel> login(String username, String password) async {
    try {
      final dio = await _getDio();
      final response = await dio.post(
        '/login',
        data: {
          'username': username.trim(),
          'password': password.trim(),
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      final token = response.data['access_token'] as String;
      await ApiConfig.setToken(token);

      // Setelah dapat token, ambil profil user saat ini
      final user = await getProfilSaya();
      return user;
    } catch (e) {
      throw _parseErrorMessage(e);
    }
  }

  // 2. PROFIL SAYA (GET /saya)
  Future<UserModel> getProfilSaya() async {
    try {
      final dio = await _getDio();
      final response = await dio.get('/saya');
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw _parseErrorMessage(e);
    }
  }

  // 3. ABSEN MASUK (POST /absen/masuk - MultipartFormData)
  Future<Map<String, dynamic>> absenMasuk({
    required double latitude,
    required double longitude,
    required File fotoFile,
  }) async {
    try {
      final dio = await _getDio();
      final fileName = 'foto_masuk_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final formData = FormData.fromMap({
        'latitude': latitude,
        'longitude': longitude,
        'foto': await MultipartFile.fromFile(
          fotoFile.path,
          filename: fileName,
        ),
      });

      final response = await dio.post(
        '/absen/masuk',
        data: formData,
      );

      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw _parseErrorMessage(e);
    }
  }

  // 4. ABSEN PULANG (POST /absen/pulang - MultipartFormData)
  Future<Map<String, dynamic>> absenPulang({
    required double latitude,
    required double longitude,
    required File fotoFile,
  }) async {
    try {
      final dio = await _getDio();
      final fileName = 'foto_pulang_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final formData = FormData.fromMap({
        'latitude': latitude,
        'longitude': longitude,
        'foto': await MultipartFile.fromFile(
          fotoFile.path,
          filename: fileName,
        ),
      });

      final response = await dio.post(
        '/absen/pulang',
        data: formData,
      );

      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw _parseErrorMessage(e);
    }
  }

  // 5. RIWAYAT PRESENSI SAYA (GET /absen/saya)
  Future<List<AbsensiModel>> getRiwayatSaya() async {
    try {
      final dio = await _getDio();
      final response = await dio.get('/absen/saya');
      if (response.data is List) {
        final list = response.data as List;
        return list
            .map((item) => AbsensiModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      throw _parseErrorMessage(e);
    }
  }
}
