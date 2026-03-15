import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:app/utils.dart';
import 'package:app/api.dart' as api;

class InitScreen extends StatefulWidget {
  const InitScreen({super.key});

  @override
  State<InitScreen> createState() => _InitScreenState();
}

class _InitScreenState extends State<InitScreen> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await DeviceIdManager.getDeviceId();

    await prefs.setString('device_id', deviceId);

    // Check if we already have authenticated tokens from OAuth
    final existingToken = prefs.getString('auth_token');
    print('INIT: existingToken = ${existingToken != null ? 'found' : 'null'}');

    if (existingToken != null) {
      // Validate token type - check if it's a user token (sub is numeric) or device token (sub is UUID)
      try {
        final decoded = JwtDecoder.decode(existingToken);
        final sub = decoded['sub'] as String?;
        final isUserToken =
            sub != null && !sub.contains('-') && sub.length < 20;
        print('INIT: Token sub = $sub, isUserToken = $isUserToken');

        if (isUserToken) {
          print('INIT: Using existing user token, going to /home');
          if (!mounted) return;
          context.go('/home');
          return;
        } else {
          print('INIT: Existing token is device token, will do device login');
        }
      } catch (e) {
        print('INIT: Error decoding token: $e');
      }
    }

    // No token - do device login
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');

    try {
      final response = await api.Api.deviceLogin(deviceId);

      if (response.containsKey('access_token')) {
        await prefs.setString('auth_token', response['access_token']);
        await prefs.setString('refresh_token', response['refresh_token']);
        if (!mounted) return;
        context.go('/home');
      } else {
        print('Device login failed: $response');
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Login failed: $response')));
      }
    } catch (e) {
      print('Device login error: $e');
      if (!mounted) return;
      final message = e is api.ApiException ? e.displayMessage : e.toString();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login error: $message')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
