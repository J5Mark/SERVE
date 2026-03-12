import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

final apiBase = 'https://serve-back.ftp.sh';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic detail;

  ApiException(this.message, {this.statusCode, this.detail});

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';

  String get displayMessage {
    if (detail != null && detail is Map && detail.containsKey('detail')) {
      return detail['detail'].toString();
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

  static Future<Map<String, dynamic>> deviceLogin(String deviceId) async {
    final res = await http.post(
      Uri.parse("$apiBase/auth/devicelogin"),
      body: jsonEncode({'device_id': deviceId}),
      headers: {'Content-Type': 'application/json'},
    );

    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> register({
    required String deviceId,
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
        'device_id': deviceId,
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'phone_number': phoneNumber,
        'email': email,
        'password': password,
        'entrep': entrep,
        'admin': false,
      }),
      headers: {'Content-Type': 'application/json'},
    );

    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> login({
    required String deviceId,
    String? username,
    String? email,
    String? phone,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse("$apiBase/auth/login"),
      body: jsonEncode({
        'device_id': deviceId,
        'username': username,
        'email': email,
        'phone': phone,
        'password': password,
      }),
      headers: {'Content-Type': 'application/json'},
    );

    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> getUser(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      throw Exception('Not authenticated: no token found');
    }
    final res = await http.get(
      Uri.parse('$apiBase/users/me'),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to get user: ${res.statusCode} - ${res.body}');
    }

    final response = jsonDecode(res.body);
    return response;
  }

  static Future<Map<String, dynamic>> getCommunity(int communityId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final res = await http.get(
      Uri.parse('$apiBase/comm/$communityId'),
      headers: {"Authorization": "Bearer $token"},
    );

    final response = jsonDecode(res.body);
    return response;
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

  static Future<String?> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('device_id');
  }

  static Future<void> setDeviceId(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_id', deviceId);
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
}
