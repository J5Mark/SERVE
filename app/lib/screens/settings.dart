import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app/api.dart';
import 'package:app/widgets.dart';
import 'package:app/logger.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarker = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    AppTheme.listener.addListener(_onThemeChange);
  }

  void _onThemeChange() {
    if (mounted) {
      setState(() {
        _isDarker = AppTheme.isDarker;
      });
    }
  }

  @override
  void dispose() {
    AppTheme.listener.removeListener(_onThemeChange);
    super.dispose();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarker = prefs.getBool('darker_theme') ?? false;
    });
  }

  Future<void> _toggleTheme(bool value) async {
    setState(() {
      _isDarker = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darker_theme', value);
    AppTheme.setDarkerMode(value);
  }

  Future<void> _checkNotificationStatus() async {
    // Check permission status
    var status = await Permission.notification.status;
    // Get FCM token
    final token = await FirebaseMessaging.instance.getToken();
    // Show dialog with info and option to request permission
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceContainer,
          title: const Text(
            'Notification Status',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Permission: ${status.isGranted ? "Granted" : "Denied"}',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'FCM Token: ${token != null ? "${token.substring(0, 20)}..." : "Not available"}',
                style: const TextStyle(color: Colors.white),
              ),
              if (!status.isGranted) ...[
                const SizedBox(height: 16),
                const Text(
                  'Tap "Request" to enable notifications.',
                  style: TextStyle(color: AppColors.onSurfaceVariant),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            if (!status.isGranted)
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await Permission.notification.request();
                  // Refresh status
                  _checkNotificationStatus();
                },
                child: const Text('Request'),
              ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showLogs() async {
    final logs = await AppLogger.getLogs();
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceContainer,
          title: const Text('App Logs', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Text(
              logs,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _clearLogs() async {
    await AppLogger.clearLogs();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Logs cleared')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(color: AppColors.onSurface)),
        backgroundColor: AppColors.surface,
      ),
      body: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Appearance',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          SwitchListTile(
            secondary: Icon(
              _isDarker ? Icons.nightlight_round : Icons.light_mode,
              color: AppColors.onSurfaceVariant,
            ),
            title: Text(
              'Darker Theme',
              style: TextStyle(color: AppColors.onSurface),
            ),
            subtitle: Text(
              _isDarker ? 'Pure black background' : 'Dark theme with contrast',
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
            value: _isDarker,
            onChanged: _toggleTheme,
            activeColor: AppColors.primary,
          ),
          const Divider(),
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Notifications',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          ListTile(
            leading: Icon(
              Icons.notifications,
              color: AppColors.onSurfaceVariant,
            ),
            title: Text(
              'Notification Settings',
              style: TextStyle(color: AppColors.onSurface),
            ),
            subtitle: Text(
              'Check permission and token',
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
            onTap: _checkNotificationStatus,
          ),
          ListTile(
            leading: Icon(Icons.article, color: AppColors.onSurfaceVariant),
            title: Text(
              'View Logs',
              style: TextStyle(color: AppColors.onSurface),
            ),
            subtitle: Text(
              'View app logs for debugging',
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
            onTap: _showLogs,
          ),
          ListTile(
            leading: Icon(
              Icons.delete_sweep,
              color: AppColors.onSurfaceVariant,
            ),
            title: Text(
              'Clear Logs',
              style: TextStyle(color: AppColors.onSurface),
            ),
            subtitle: Text(
              'Clear all logs',
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
            onTap: _clearLogs,
          ),
          const Divider(),
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Account',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.logout, color: AppColors.onSurfaceVariant),
            title: Text('Logout', style: TextStyle(color: AppColors.onSurface)),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('auth_token');
              await prefs.remove('refresh_token');
              if (context.mounted) {
                context.go('/init');
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'Delete Profile',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () => _showDeleteProfileDialog(context),
          ),
        ],
      ),
    );
  }

  void _showDeleteProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: const Text(
          'Delete Profile',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete your profile? This action cannot be undone.',
          style: TextStyle(color: AppColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteProfile(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProfile(BuildContext context) async {
    try {
      await Api.deleteProfile();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('refresh_token');
      if (context.mounted) {
        context.go('/init');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
