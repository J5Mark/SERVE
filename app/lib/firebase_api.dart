import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/api.dart';
import 'package:app/firebase_options.dart';
import 'package:app/global_keys.dart';
import 'package:app/logger.dart';
import 'package:go_router/go_router.dart';

class FirebaseApi {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initNotifications() async {
    if (kIsWeb) {
      AppLogger.log('Notifications init: web platform, skipping');
      return;
    }

    AppLogger.log('Notifications init: starting');

    // Step 1: Request permission for Firebase Messaging
    try {
      AppLogger.log('Notifications init: requesting Firebase permission');
      await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      AppLogger.log('Notifications init: Firebase permission granted');
    } catch (e) {
      AppLogger.log('Notifications init: Firebase permission error: $e');
    }

    // Step 2: Request notification permission for Android 13+
    if (Platform.isAndroid) {
      try {
        AppLogger.log(
          'Notifications init: requesting Android notification permission',
        );
        await Permission.notification.request();
        AppLogger.log(
          'Notifications init: Android notification permission granted',
        );
      } catch (e) {
        AppLogger.log('Notifications init: Android permission error: $e');
      }
    }

    // Step 3: Get FCM token and send to backend if user is logged in
    try {
      AppLogger.log('Notifications init: getting FCM token');
      final token = await _firebaseMessaging.getToken();
      AppLogger.log('FCM Token: $token');

      if (token != null) {
        // Save token to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', token);

        // Check if user is logged in (has auth token)
        final authToken = prefs.getString('auth_token');
        if (authToken != null && authToken.isNotEmpty) {
          try {
            await Api.registerDeviceToken(token);
            AppLogger.log('FCM token sent to backend');
          } catch (e) {
            AppLogger.log('Failed to send FCM token to backend: $e');
          }
        }

        // Set up token refresh listener
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
          AppLogger.log('FCM Token refreshed: $newToken');
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('fcm_token', newToken);

          final authToken = prefs.getString('auth_token');
          if (authToken != null && authToken.isNotEmpty) {
            try {
              await Api.registerDeviceToken(newToken);
              AppLogger.log('Refreshed FCM token sent to backend');
            } catch (e) {
              AppLogger.log('Failed to send refreshed FCM token: $e');
            }
          }
        });
      }
    } catch (e) {
      AppLogger.log('Notifications init: FCM token error: $e');
    }

    // Step 4: Initialize local notifications
    try {
      AppLogger.log('Notifications init: initializing local notifications');
      const AndroidInitializationSettings androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings darwinInit =
          DarwinInitializationSettings(
            requestAlertPermission:
                false, // already requested via requestPermission
            requestBadgePermission: false,
            requestSoundPermission: false,
          );

      await _flutterLocalNotificationsPlugin.initialize(
        InitializationSettings(
          android: androidInit,
          iOS: darwinInit,
          macOS: darwinInit,
        ),
        onDidReceiveNotificationResponse: _onNotificationTap,
      );
      AppLogger.log('Notifications init: local notifications initialized');
    } catch (e) {
      AppLogger.log('Notifications init: local notifications init error: $e');
    }

    // Step 5: Create Android notification channel
    if (Platform.isAndroid) {
      try {
        AppLogger.log(
          'Notifications init: creating Android notification channel',
        );
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'high_importance_channel',
          'Important notifications',
          description: 'Main push notification channel for SERVE',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );

        await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(channel);
        AppLogger.log('Notifications init: channel created');
      } catch (e) {
        AppLogger.log('Notifications init: channel creation error: $e');
      }
    }

    // Step 6: Set up foreground message listener
    try {
      AppLogger.log(
        'Notifications init: setting up foreground message listener',
      );
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      AppLogger.log('Notifications init: foreground listener set');
    } catch (e) {
      AppLogger.log('Notifications init: foreground listener error: $e');
    }

    // Step 7: Set up onMessageOpenedApp listener
    try {
      AppLogger.log(
        'Notifications init: setting up onMessageOpenedApp listener',
      );
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      AppLogger.log('Notifications init: onMessageOpenedApp listener set');
    } catch (e) {
      AppLogger.log(
        'Notifications init: onMessageOpenedApp listener error: $e',
      );
    }

    // Step 8: Handle initial message (app opened from terminated state)
    try {
      AppLogger.log('Notifications init: checking for initial message');
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        AppLogger.log('Notifications init: initial message received');
        _handleNotificationTap(initialMessage);
      } else {
        AppLogger.log('Notifications init: no initial message');
      }
    } catch (e) {
      AppLogger.log('Notifications init: initial message error: $e');
    }

    AppLogger.log('Notifications init: completed');
  }

  void _handleForegroundMessage(RemoteMessage message) {
    try {
      AppLogger.log('Foreground data message: ${message.data}');
      final title = message.data['title'] ?? 'Notification';
      final body = message.data['body'] ?? '';
      if (title.isNotEmpty || body.isNotEmpty) {
        showLocalNotification(message);
      }
    } catch (e) {
      AppLogger.log('Foreground message handler error: $e');
    }
  }

  Future<void> showLocalNotification(RemoteMessage message) async {
    try {
      final title = message.data['title'] ?? 'Notification';
      final body = message.data['body'] ?? '';
      final payload = jsonEncode(message.data);

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'high_importance_channel',
            'Important notifications',
            channelDescription: 'Main push notification channel for SERVE',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
          );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        0,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e, stack) {
      AppLogger.log('Show notification error: $e\\n$stack');
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    try {
      _navigateWithData(message.data);
    } catch (e) {
      AppLogger.log('Notification tap handler error: $e');
    }
  }

  void _navigateWithData(Map<String, dynamic> data) {
    AppLogger.log('Notification navigation data: $data');
    String? route;

    if (data.containsKey('route')) {
      route = data['route'];
    } else if (data.containsKey('type') && data.containsKey('id')) {
      final type = data['type'];
      final id = data['id'];
      switch (type) {
        case 'chat':
          route = '/chat/$id';
          break;
        case 'post':
          route = '/post/$id';
          break;
        case 'business':
          route = '/business/$id';
          break;
        case 'community':
          route = '/community/$id';
          break;
        case 'analysis':
          route = '/analysis/$id';
          break;
        case 'edit-community':
          route = '/edit-community/$id';
          break;
        default:
          route = '/home';
      }
    } else {
      route = '/home';
    }

    AppLogger.log('Notification navigation route: $route');
    final context = navigatorKey.currentContext;
    if (context != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          GoRouter.of(context).go(route!);
        } catch (e) {
          AppLogger.log('GoRouter navigation error: $e');
        }
      });
    } else {
      try {
        navigatorKey.currentState?.pushNamed(route!);
      } catch (e) {
        AppLogger.log('Navigator navigation error: $e');
      }
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _navigateWithData(data);
      } catch (e) {
        AppLogger.log('Error parsing notification payload: $e');
      }
    }
  }
}

// Top-level background message handler
@pragma('vm:entry-point')
Future<void> handleBackgroundMessage(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AppLogger.log('Background message received: ${message.messageId}');
    // Do not show notification here; let foreground listener show when app starts
  } catch (e) {
    AppLogger.log('Background handler error: $e');
  }
}
