import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

enum AuthState { initial, authenticated, unauthenticated }

final authStateProvider = ChangeNotifierProvider<AuthStateNotifier>((ref) {
  return AuthStateNotifier();
});

class AuthStateNotifier extends ChangeNotifier {
  AuthState _state = AuthState.initial;
  SharedPreferences? _prefs;

  AuthState get state => _state;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _checkToken();

    // Check for tokens in URL (for OAuth redirect)
    await _checkUrlTokens();
  }

  Future<void> _checkUrlTokens() async {
    // This will be called from main.dart with URL tokens
    // For now, just a placeholder - tokens are handled in router redirect
  }

  Future<void> saveTokensFromUrl(
    String? accessToken,
    String? refreshToken,
    String? userId,
  ) async {
    print(
      'AUTH_PROVIDER: saveTokensFromUrl called, access=${accessToken != null ? 'yes' : 'no'}, refresh=${refreshToken != null ? 'yes' : 'no'}, userId=$userId',
    );

    if (accessToken == null || refreshToken == null) {
      print('AUTH_PROVIDER: saveTokensFromUrl ABORTED - missing tokens');
      return;
    }

    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString('auth_token', accessToken);
    await _prefs!.setString('refresh_token', refreshToken);
    // Anonymous ID is managed separately
    await _prefs!.setString('auth_token_source', 'oauth');
    _state = AuthState.authenticated;
    print('AUTH_PROVIDER: auth_token set to oauth, state set to authenticated');
    notifyListeners();

    // Verify the save
    final verifyToken = _prefs!.getString('auth_token');
    final verifySource = _prefs!.getString('auth_token_source');
    print(
      'AUTH_PROVIDER: Verify save - token=${verifyToken != null ? 'saved' : 'NOT SAVED'}, source=$verifySource',
    );
  }

  Future<void> _checkToken() async {
    if (_prefs == null) return;

    final token = _prefs!.getString('auth_token');

    if (token == null) {
      _state = AuthState.unauthenticated;
      notifyListeners();
      return;
    }

    bool isTokenValid = true;
    try {
      isTokenValid = !JwtDecoder.isExpired(token);
    } catch (e) {
      isTokenValid = false;
    }

    if (!isTokenValid) {
      await _prefs!.remove('auth_token');
      await _prefs!.remove('refresh_token');
      _state = AuthState.unauthenticated;
    } else {
      _state = AuthState.authenticated;
    }
    notifyListeners();
  }

  Future<void> setAuthenticated(
    String accessToken,
    String refreshToken, {
    String? userId,
  }) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString('auth_token', accessToken);
    await _prefs!.setString('refresh_token', refreshToken);
    // Anonymous ID is managed by AnonymousIdManager
    _state = AuthState.authenticated;
    notifyListeners();
  }

  Future<void> logout() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove('auth_token');
    await _prefs!.remove('refresh_token');
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isUnauthenticated => _state == AuthState.unauthenticated;
}
