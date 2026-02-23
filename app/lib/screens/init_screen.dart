import 'package:flutter/material.dart';
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

    print(deviceId);
    final response = await api.Api.deviceLogin(deviceId);
    print(response);

    await prefs.setString('auth_token', response['access_token']);
    await prefs.setString('refresh_token', response['refresh_token']);

    print(response['access_token']);
    if (!mounted) return;

    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
