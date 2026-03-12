import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');

    print(deviceId);

    try {
      final response = await api.Api.deviceLogin(deviceId);
      print(response);

      if (response.containsKey('access_token')) {
        await prefs.setString('auth_token', response['access_token']);
        await prefs.setString('refresh_token', response['refresh_token']);
        print(response['access_token']);
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
