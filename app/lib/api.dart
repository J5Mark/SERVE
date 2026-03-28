import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'utils.dart';

final apiBase = 'https://serveyourcommunity.ftp.sh/api';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic detail;

  ApiException(this.message, {this.statusCode, this.detail});

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';

  String get displayMessage {
    if (detail != null) {
      if (detail is Map) {
        if (detail.containsKey('detail')) {
          return detail['detail'].toString();
        }
        return detail.toString();
      }
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
    }
    if (statusCode != null) {
      return '$message (status: $statusCode)';
    }
    return message;
  }
}

class Api {
  static Map<String, dynamic> _handleResponse(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return {};
      return jsonDecode(res.body);
    }

    dynamic detail;
    try {
      if (res.body.isNotEmpty) {
        detail = jsonDecode(res.body);
      }
    } catch (_) {
      detail = res.body;
    }

    throw ApiException(
      'Request failed',
      statusCode: res.statusCode,
      detail: detail,
    );
  }

  static Future<Map<String, dynamic>> register({
    required String username,
    required String firstName,
    String? lastName,
    String? phoneNumber,
    String? email,
    required String password,
    bool entrep = false,
  }) async {
    final res = await http.post(
      Uri.parse("$apiBase/users/register"),
      body: jsonEncode({
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'phone_number': phoneNumber,
        'email': email,
        'password': password,
        'entrep': entrep,
      }),
      headers: {'Content-Type': 'application/json'},
    );

    return _handleResponse(res);
  }

  static Future<void> sendEmailVerificationCode() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    await http.post(
      Uri.parse("$apiBase/auth/send_codes/email"),
      body: jsonEncode({}),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
  }

  static Future<void> sendPhoneVerificationCode() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    await http.post(
      Uri.parse("$apiBase/auth/send_codes/phone"),
      body: jsonEncode({}),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
  }

  static Future<Map<String, dynamic>> verifyEmailCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.post(
      Uri.parse("$apiBase/auth/check_codes"),
      body: jsonEncode({'code': code, 'type': 'email'}),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> verifyPhoneCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.post(
      Uri.parse("$apiBase/auth/check_codes"),
      body: jsonEncode({'code': code, 'type': 'phone'}),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> login({
    String? username,
    String? email,
    String? phone,
    required String password,
  }) async {
    final body = <String, dynamic>{
      'password': password,
      'username': username,
      'email': email,
      'phone': phone,
    };

    final res = await http.post(
      Uri.parse("$apiBase/auth/login"),
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> sendVerificationEmail(
    String email,
  ) async {
    final res = await http.post(
      Uri.parse("$apiBase/auth/send_verify_email"),
      body: jsonEncode({'email': email}),
      headers: {'Content-Type': 'application/json'},
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> verifyEmail(
    String email,
    String code,
  ) async {
    final res = await http.post(
      Uri.parse("$apiBase/auth/verify_email"),
      body: jsonEncode({'email': email, 'code': code}),
      headers: {'Content-Type': 'application/json'},
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> sendVerificationPhone(
    String phone,
  ) async {
    final res = await http.post(
      Uri.parse("$apiBase/auth/send_verify_phone"),
      body: jsonEncode({'phone': phone}),
      headers: {'Content-Type': 'application/json'},
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> verifyPhone(
    String phone,
    String code,
  ) async {
    final res = await http.post(
      Uri.parse("$apiBase/auth/verify_phone"),
      body: jsonEncode({'phone': phone, 'code': code}),
      headers: {'Content-Type': 'application/json'},
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> updateCommunity({
    required int communityId,
    required String name,
    required String description,
    String? redditLink,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.post(
      Uri.parse("$apiBase/comm/edit"),
      body: jsonEncode({
        'community_id': communityId,
        'name': name,
        'description': description,
        'reddit_link': redditLink,
      }),
      headers: {
        'Content-Type': 'application/json',
        "Authorization": "Bearer $token",
      },
    );
    return _handleResponse(res);
  }

  static Future<List<dynamic>> getCommunities() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.get(
      Uri.parse('$apiBase/comm/'),
      headers: {"Authorization": "Bearer $token"},
    );

    final response = jsonDecode(res.body);
    if (response is List) return response;
    return [];
  }

  static Future<List<dynamic>> discoverCommunities({
    required int n,
    required int offset,
    required String sorting,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.post(
      Uri.parse('$apiBase/comm/list_communities'),
      body: jsonEncode({'n': n, 'offset': offset, 'sorting': sorting}),
      headers: {
        'Content-Type': 'application/json',
        "Authorization": "Bearer $token",
      },
    );

    final response = jsonDecode(res.body);
    print(response);
    if (response is List) return response;
    return [];
  }

  static Future<Map<String, dynamic>> joinCommunity(int communityId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.post(
      Uri.parse('$apiBase/comm/join'),
      body: jsonEncode({'community_id': communityId}),
      headers: {
        'Content-Type': 'application/json',
        "Authorization": "Bearer $token",
      },
    );

    final data = jsonDecode(res.body);
    return data;
  }

  static Future<Map<String, dynamic>> leaveCommunity(int communityId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.post(
      Uri.parse('$apiBase/comm/leave'),
      body: jsonEncode({'community_id': communityId}),
      headers: {
        'Content-Type': 'application/json',
        "Authorization": "Bearer $token",
      },
    );

    final data = jsonDecode(res.body);
    return data;
  }

  static Future<Map<String, dynamic>> getCommunity(int communityId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.get(
      Uri.parse('$apiBase/comm/$communityId'),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return {};
      return jsonDecode(res.body);
    }
    throw Exception('Failed to load community (status: ${res.statusCode})');
  }

  static Future<Map<String, dynamic>> getCommunityUnauth(
    int communityId,
  ) async {
    final res = await http.get(Uri.parse('$apiBase/comm/unauth/$communityId'));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return {};
      return jsonDecode(res.body);
    }
    throw Exception('Failed to load community (status: ${res.statusCode})');
  }

  static Future<Map<String, dynamic>> createCommunity({
    required String name,
    required String description,
    String? redditLink,
    required String slug,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (redditLink != null) {
      final subExistsRes = await http.get(
        Uri.parse("$apiBase/integrations/reddit/check-community/$redditLink"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': "Bearer $token",
        },
      );

      final subExistsData = _handleResponse(subExistsRes);

      if (subExistsData['subreddit'] != true) {
        return {'subreddit': 'doesnt exist'};
      }
    }
    final res = await http.post(
      Uri.parse("$apiBase/comm/create"),
      body: jsonEncode({
        'name': name,
        'description': description,
        'reddit_link': redditLink,
        'slug': slug,
      }),
      headers: {
        'Content-Type': 'application/json',
        "Authorization": "Bearer $token",
      },
    );

    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> createBusiness({
    required String name,
    required String bio,
    required List<int> communityIds,
    String? contGoal,
    int? reactionTimeDays,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final body = {'name': name, 'bio': bio, 'community_ids': communityIds};
    if (contGoal != null) body['cont_goal'] = contGoal;
    if (reactionTimeDays != null) body['reaction_time'] = reactionTimeDays;

    final res = await http.post(
      Uri.parse("$apiBase/business/create"),
      body: jsonEncode(body),
      headers: {
        'Content-Type': 'application/json',
        "Authorization": "Bearer $token",
      },
    );

    return _handleResponse(res);
  }

  static Future<List<dynamic>> getUserBusinesses() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.get(
      Uri.parse('$apiBase/users/me'),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to get user: ${res.statusCode} - ${res.body}');
    }

    final response = jsonDecode(res.body);
    final businesses = response['businesses'] as List? ?? [];
    return businesses;
  }

  static Future<Map<String, dynamic>> getBusiness(int businessId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.get(
      Uri.parse('$apiBase/business/$businessId'),
      headers: {"Authorization": "Bearer $token"},
    );

    final response = jsonDecode(res.body);
    return response;
  }

  static Future<Map<String, dynamic>> editBusiness({
    required int businessId,
    String? bio,
    List<int>? communityIds,
    String? contGoal,
    int? reactionTimeDays,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final body = <String, dynamic>{};
    if (bio != null) body['bio'] = bio;
    if (communityIds != null) body['community_ids'] = communityIds;
    if (contGoal != null) body['cont_goal'] = contGoal;
    if (reactionTimeDays != null) body['reaction_time'] = reactionTimeDays;

    final res = await http.post(
      Uri.parse("$apiBase/business/edit/$businessId"),
      body: jsonEncode(body),
      headers: {
        'Content-Type': 'application/json',
        "Authorization": "Bearer $token",
      },
    );

    final data = jsonDecode(res.body);
    return data;
  }

  static Future<List<dynamic>> getNewcomerBusinesses(int n) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.get(
      Uri.parse('$apiBase/business/newcomers/$n'),
      headers: {"Authorization": "Bearer $token"},
    );

    final response = jsonDecode(res.body);
    if (response is List) return response;
    return [];
  }

  static Future<Map<String, dynamic>> verifyBusiness(
    int businessId,
    String type,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.post(
      Uri.parse("$apiBase/business/verify"),
      body: jsonEncode({'business_id': businessId, 'type': type}),
      headers: {
        'Content-Type': 'application/json',
        "Authorization": "Bearer $token",
      },
    );

    final data = jsonDecode(res.body);
    return data;
  }

  static Future<Map<String, dynamic>> createPost({
    required String name,
    required String contents,
    required int communityId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.post(
      Uri.parse("$apiBase/post/c"),
      body: jsonEncode({
        'name': name,
        'contents': contents,
        'community_id': communityId,
      }),
      headers: {
        'Content-Type': 'application/json',
        "Authorization": "Bearer $token",
      },
    );

    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> getPost(int postId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.get(
      Uri.parse('$apiBase/post/g/$postId'),
      headers: {"Authorization": "Bearer $token"},
    );

    final response = jsonDecode(res.body);
    return response;
  }

  static Future<Map<String, dynamic>> voteOnPost({
    required int postId,
    required double wouldPay,
    String? competition,
    String? problems,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    print('Vote token: $token');
    final res = await http.post(
      Uri.parse("$apiBase/post/vote"),
      body: jsonEncode({
        'post_id': postId,
        'would_pay': wouldPay,
        'competition': competition,
        'problems': problems,
      }),
      headers: {
        'Content-Type': 'application/json',
        "Authorization": "Bearer $token",
      },
    );
    print('Vote response: ${res.statusCode} - ${res.body}');

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Vote failed: ${res.statusCode} - ${res.body}');
    }

    final data = jsonDecode(res.body);
    return data;
  }

  static Future<Map<String, dynamic>> deletePost(int postId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.delete(
      Uri.parse('$apiBase/post/d/$postId'),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to delete post: ${res.statusCode} - ${res.body}');
    }

    final data = jsonDecode(res.body);
    return data;
  }

  static Future<List<dynamic>> getPosts(int n, int offset) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.get(
      Uri.parse('$apiBase/post/list/$n/$offset'),
      headers: {"Authorization": "Bearer $token"},
    );

    final response = jsonDecode(res.body);
    print(response);
    if (response is List) return response;
    return response['posts'] ?? [];
  }

  static Future<List<dynamic>> getPopularPosts(int n, int offset) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.get(
      Uri.parse('$apiBase/post/list_popular/$n/$offset'),
      headers: {"Authorization": "Bearer $token"},
    );

    final response = jsonDecode(res.body);
    print(response);
    if (response is List) return response;
    return response['posts'] ?? [];
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

  static Future<String> getAnonymousId() async {
    return AnonymousIdManager.getAnonymousId();
  }

  static Future<Map<String, dynamic>> getUser() async {
    final userId = await getCurrentUserId();
    if (userId == null) {
      throw Exception('Not authenticated');
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final response = await http.get(
      Uri.parse('$apiBase/users/$userId'),
      headers: token != null ? {"Authorization": "Bearer $token"} : {},
    );
    if (response.statusCode != 200) {
      throw ApiException('Failed to get user', statusCode: response.statusCode);
    }
    return json.decode(response.body);
  }

  static Future<bool> _isTokenExpired(String token) async {
    try {
      return JwtDecoder.isExpired(token);
    } catch (_) {
      return true;
    }
  }

  static Future<void> _ensureValidToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final refreshToken = prefs.getString('refresh_token');

    if (token == null || refreshToken == null) {
      throw Exception('No tokens available');
    }

    final isExpired = await _isTokenExpired(token);
    if (isExpired) {
      print('API: Token expired, refreshing...');
      final result = await _performTokenRefresh(refreshToken);
      if (result.containsKey('error')) {
        throw Exception('Token refresh failed: ${result['error']}');
      }
      print('API: Token refreshed successfully');
    }
  }

  static Future<Map<String, dynamic>> _performTokenRefresh(
    String refreshToken,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final res = await http.post(
        Uri.parse('$apiBase/auth/refresh'),
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

  static Future<Map<String, dynamic>> _getAuthHeaders() async {
    await _ensureValidToken();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {"Authorization": "Bearer $token"};
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
        Uri.parse('$apiBase/auth/refresh'),
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

  static Future<bool> hasToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') != null;
  }

  static Future<List<dynamic>> searchPosts(String query, int n) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (query.startsWith('c:')) {
      final communityQuery = query.substring(2).trim();
      return searchCommunities(communityQuery, n);
    }

    final res = await http.post(
      Uri.parse('$apiBase/post/search'),
      body: jsonEncode({'query': query, 'n': n}),
      headers: {
        'Content-Type': 'application/json',
        "Authorization": "Bearer $token",
      },
    );

    final response = jsonDecode(res.body);
    print(response);
    if (response is List) return response;
    return [];
  }

  static Future<List<dynamic>> searchCommunities(String query, int n) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.post(
      Uri.parse('$apiBase/comm/search'),
      body: jsonEncode({'query': query, 'n': n}),
      headers: {
        'Content-Type': 'application/json',
        "Authorization": "Bearer $token",
      },
    );

    final response = jsonDecode(res.body);
    if (response is List) return response;
    return [];
  }

  static Future<Map<String, dynamic>> updateUser(
    int userId, {
    String? username,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final body = <String, dynamic>{};
    if (username != null) body['username'] = username;
    if (firstName != null) body['first_name'] = firstName;
    if (lastName != null) body['last_name'] = lastName;
    if (phoneNumber != null) body['phone_number'] = phoneNumber;
    if (email != null) body['email'] = email;

    final res = await http.patch(
      Uri.parse('$apiBase/users/$userId'),
      body: jsonEncode(body),
      headers: {
        'Content-Type': 'application/json',
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to update user: ${res.statusCode} - ${res.body}');
    }

    final data = jsonDecode(res.body);
    return data;
  }

  static Future<List<dynamic>> getContacts(
    int n,
    int communityId,
    int postId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.post(
      Uri.parse('$apiBase/business/get_contacts'),
      body: jsonEncode({
        'n': n,
        'community_id': communityId,
        'post_id': postId,
      }),
      headers: {
        'Content-Type': 'application/json',
        "Authorization": "Bearer $token",
      },
    );

    final response = jsonDecode(res.body);
    if (response is List) return response;
    return [];
  }

  static Future<List<dynamic>> getCommunityPosts({
    required int communityId,
    required int n,
    required int offset,
    required String sorting,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.post(
      Uri.parse('$apiBase/post/community/posts'),
      body: jsonEncode({
        'community_id': communityId,
        'n': n,
        'offset': offset,
        'sorting': sorting,
      }),
      headers: {
        'Content-Type': 'application/json',
        "Authorization": "Bearer $token",
      },
    );

    final response = jsonDecode(res.body);
    if (response is List) return response;
    return [];
  }

  static Future<Map<String, dynamic>> addContacts(List<int> contactIds) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.post(
      Uri.parse('$apiBase/business/connect'),
      body: jsonEncode({'contact_ids': contactIds}),
      headers: {
        'Content-Type': 'application/json',
        "Authorization": "Bearer $token",
      },
    );

    final data = jsonDecode(res.body);
    return data;
  }

  // Chat API methods
  static Future<List<dynamic>> getConversations(int n, int offset) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.get(
      Uri.parse('$apiBase/chats/?n=$n&offset=$offset'),
      headers: {"Authorization": "Bearer $token"},
    );

    final response = jsonDecode(res.body);
    if (response is List) return response;
    return [];
  }

  static Future<dynamic> getChat(int conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.get(
      Uri.parse('$apiBase/chats/$conversationId/20/0'),
      headers: {"Authorization": "Bearer $token"},
    );

    final data = jsonDecode(res.body);
    return data;
  }

  static Future<Map<String, dynamic>> createConversation(
    int targetUserId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.post(
      Uri.parse('$apiBase/chats/$targetUserId/create'),
      headers: {"Authorization": "Bearer $token"},
    );

    final data = jsonDecode(res.body);
    return data;
  }

  static Future<Map<String, dynamic>> sendMessage(
    int conversationId,
    String content,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.post(
      Uri.parse('$apiBase/chats/$conversationId'),
      body: jsonEncode({'content': content}),
      headers: {
        'Content-Type': 'application/json',
        "Authorization": "Bearer $token",
      },
    );

    final data = jsonDecode(res.body);
    return data;
  }

  static Future<Map<String, dynamic>> deleteProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.delete(
      Uri.parse('$apiBase/users/me'),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode != 200) {
      throw Exception(
        'Failed to delete profile: ${res.statusCode} - ${res.body}',
      );
    }

    final data = jsonDecode(res.body);
    return data;
  }

  static Future<Map<String, dynamic>> requestAnalysis(
    int postId, {
    bool fullAnalysis = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.post(
      Uri.parse('$apiBase/post/analyze/$postId?full_analysis=$fullAnalysis'),
      headers: {
        'Content-Type': 'application/json',
        "Authorization": "Bearer $token",
      },
    );

    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> getAnalysis(int postId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.get(
      Uri.parse('$apiBase/post/analysis/$postId'),
      headers: {"Authorization": "Bearer $token"},
    );

    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> getAnalysisStatus(int postId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.get(
      Uri.parse('$apiBase/post/analysis_status/$postId'),
      headers: {"Authorization": "Bearer $token"},
    );

    return _handleResponse(res);
  }

  static Future<List<dynamic>> getMyAnalyses(int n, int offset) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.get(
      Uri.parse('$apiBase/post/analyses/my/$n/$offset'),
      headers: {"Authorization": "Bearer $token"},
    );

    final response = jsonDecode(res.body);
    if (response is List) return response;
    return [];
  }

  static Future<Map<String, dynamic>> submitFeedback(String contents) async {
    await _ensureValidToken();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.post(
      Uri.parse('$apiBase/feedback'),
      body: jsonEncode({'contents': contents}),
      headers: {
        'Content-Type': 'application/json',
        "Authorization": "Bearer $token",
      },
    );

    return _handleResponse(res);
  }

  static String getUserAvatarUrl(int userId) {
    return '$apiBase/users/avatar/$userId';
  }

  static String getCommunityAvatarUrl(int communityId) {
    return '$apiBase/comm/avatar/$communityId';
  }

  static String getBusinessAvatarUrl(int businessId) {
    return '$apiBase/business/avatar/$businessId';
  }

  static String getPostImageUrl(int postId) {
    return '$apiBase/post/image/$postId';
  }

  static Future<Map<String, dynamic>> uploadUserAvatar(
    int userId,
    List<int> imageBytes,
  ) async {
    await _ensureValidToken();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$apiBase/users/add_avatar'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes('image', imageBytes, filename: 'avatar.jpg'),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> uploadCommunityAvatar(
    int communityId,
    List<int> imageBytes,
  ) async {
    await _ensureValidToken();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$apiBase/comm/avatar'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['community_id'] = communityId.toString();
    request.files.add(
      http.MultipartFile.fromBytes('image', imageBytes, filename: 'avatar.jpg'),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> uploadBusinessAvatar(
    int businessId,
    List<int> imageBytes,
  ) async {
    await _ensureValidToken();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$apiBase/business/avatar'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['business_id'] = businessId.toString();
    request.files.add(
      http.MultipartFile.fromBytes('image', imageBytes, filename: 'avatar.jpg'),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> uploadPostImage(
    int postId,
    List<int> imageBytes,
  ) async {
    await _ensureValidToken();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$apiBase/post/image/$postId'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes('image', imageBytes, filename: 'image.jpg'),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> deleteUserAvatar(int userId) async {
    await _ensureValidToken();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.delete(
      Uri.parse('$apiBase/users/avatar/$userId'),
      headers: {"Authorization": "Bearer $token"},
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> deleteCommunityAvatar(
    int communityId,
  ) async {
    await _ensureValidToken();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.delete(
      Uri.parse('$apiBase/comm/avatar/$communityId'),
      headers: {"Authorization": "Bearer $token"},
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> deleteBusinessAvatar(
    int businessId,
  ) async {
    await _ensureValidToken();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.delete(
      Uri.parse('$apiBase/business/avatar/$businessId'),
      headers: {"Authorization": "Bearer $token"},
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> deletePostImage(int postId) async {
    await _ensureValidToken();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.delete(
      Uri.parse('$apiBase/post/image/$postId'),
      headers: {"Authorization": "Bearer $token"},
    );
    return _handleResponse(res);
  }
}
