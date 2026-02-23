import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

final apiBase = 'https://my-back.loca.lt/';

class Api {
  static Future<Map<String, dynamic>> deviceLogin(String deviceId) async {
    // TODO Implement the EP on the backend
    final res = await http.post(
      Uri.parse("$apiBase/auth/devicelogin"),
      body: jsonEncode({'device_id': deviceId}),
      headers: {'Content-Type': 'application/json'},
    );

    final data = jsonDecode(res.body);
    return data;
  }

  static Future<Map<String, dynamic>> getUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.get(
      Uri.parse('$apiBase/get_user/$userId'),
      headers: {"Authorization": "Bearer $token"},
    );

    final response = jsonDecode(res.body);
    return response;
  }

  static Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return null;
    try {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      return decodedToken['sub'];
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final refreshToken = prefs.getString('refresh_token');

    if (token == null || refreshToken == null) {
      return {'error': 'No tokens available'};
    }

    try {
      final res = await http.post(
        Uri.parse('$apiBase/refresh'),
        body: jsonEncode({'refresh_token': refreshToken}),
        headers: {'Content-Type': 'application/json'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        await prefs.setString('auth_token', data['access_token']);

        if (data.containsKey('refresh_token')) {
          await prefs.setString('refresh_token', data['refresh_token']);
        }

        return data;
      } else {
        await prefs.remove('auth_token');
        await prefs.remove('refresh_token');
        return {'error': 'Refresh failed', 'statusCode': res.statusCode};
      }
    } catch (e) {
      return {'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.get(
      Uri.parse('$apiBase/user/me'),
      headers: {"Authorization": "Bearer $token"},
    );

    final response = jsonDecode(res.body);
    return response;
  }

  static Future<List<dynamic>> getPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.get(
      Uri.parse('$apiBase/get_posts'),
      headers: {"Authorization": "Bearer $token"},
    );

    final response = jsonDecode(res.body);
    if (response is List) {
      return response;
    }
    return response['posts'] ?? [];
  }

  static Future<List<dynamic>> getPopularPosts() async {
    final res = await http.get(Uri.parse('$apiBase/get_popular'));

    final response = jsonDecode(res.body);
    if (response is List) {
      return response;
    }
    return response['posts'] ?? [];
  }

  static Future<bool> hasToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') != null;
  }
}
