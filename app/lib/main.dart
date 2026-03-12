import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:app/screens/posts.dart';
import 'package:app/screens/me.dart';
import 'package:app/screens/settings.dart';
import 'package:app/screens/init_screen.dart';
import 'package:app/screens/register.dart';
import 'package:app/screens/createpost.dart';
import 'package:app/screens/createbusiness.dart';
import 'package:app/screens/createcommunity.dart';
import 'package:app/screens/newcomers.dart';
import 'package:app/screens/searchpost.dart';
import 'package:app/screens/postdetail.dart';
import 'package:app/screens/business_detail.dart';
import 'package:app/screens/community_posts.dart';
import 'package:app/screens/chats.dart';
import 'package:app/screens/chat.dart';
import 'package:app/widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Handle deep link on startup
  // This will be handled by the router after initialization
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Community App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      routerConfig: _router,
    );
  }
}

final GoRouter _router = GoRouter(
  initialLocation: '/init',

  redirect: (BuildContext context, GoRouterState state) async {
    // Handle deep links
    final uriString = state.uri.toString();

    // Handle custom scheme: serve-app://auth?token=xxx
    if (uriString.startsWith('serve-app://')) {
      String path = uriString.substring('serve-app://'.length);
      if (!path.startsWith('/')) {
        path = '/$path';
      }
      return path;
    }

    // Handle Universal Links: https://serve-back.ftp.sh/auth?token=xxx
    if (uriString.contains('serve-back.ftp.sh')) {
      // Extract path and query from full URL
      final uri = Uri.parse(uriString);
      String path = uri.path;
      if (uri.queryParameters.isNotEmpty) {
        path +=
            '?' +
            uri.queryParameters.entries
                .map((e) => '${e.key}=${e.value}')
                .join('&');
      }
      return path;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final isOnInit = state.matchedLocation == '/init';

    if (token == null) {
      if (!isOnInit) return '/init';
      return null;
    }

    bool isTokenValid = true;
    try {
      isTokenValid = !JwtDecoder.isExpired(token);
    } catch (e) {
      isTokenValid = false;
    }

    if (!isTokenValid) {
      await prefs.remove('auth_token');
      await prefs.remove('refresh_token');
      if (!isOnInit) return '/init';
      return null;
    }

    if (isOnInit) {
      return '/home';
    }

    return null;
  },

  routes: [
    GoRoute(
      path: '/auth',
      builder: (context, state) {
        // Handle deep link from Google OAuth: https://serve-back.ftp.sh/auth?access_token=xxx&refresh_token=xxx&user_id=xxx
        final uri = state.uri;
        final accessToken = uri.queryParameters['access_token'];
        final refreshToken = uri.queryParameters['refresh_token'];
        final userId = uri.queryParameters['user_id'];

        if (accessToken != null && refreshToken != null) {
          // Save tokens and redirect to home
          _saveOAuthTokens(accessToken, refreshToken, userId);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/home');
          });
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    ),
    GoRoute(
      path: '/auth/google/success',
      builder: (context, state) {
        // Same as /auth - handle tokens from success page
        final uri = state.uri;
        final accessToken = uri.queryParameters['access_token'];
        final refreshToken = uri.queryParameters['refresh_token'];
        final userId = uri.queryParameters['user_id'];

        if (accessToken != null && refreshToken != null) {
          _saveOAuthTokens(accessToken, refreshToken, userId);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/home');
          });
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    ),
    GoRoute(path: '/init', builder: (context, state) => const InitScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/create-post',
      builder: (context, state) => const CreatePostScreen(),
    ),
    GoRoute(
      path: '/create-business',
      builder: (context, state) => const CreateBusinessScreen(),
    ),
    GoRoute(
      path: '/create-community',
      builder: (context, state) => const CreateCommunityScreen(),
    ),
    GoRoute(
      path: '/chat/:id',
      builder: (context, state) {
        final conversationId = int.parse(state.pathParameters['id']!);
        return ChatScreen(conversationId: conversationId);
      },
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchPostScreen(),
    ),
    GoRoute(
      path: '/post/:id',
      builder: (context, state) {
        final postId = int.parse(state.pathParameters['id']!);
        return PostDetailScreen(postId: postId);
      },
    ),
    // Deep link route for serve-app://post/:id
    GoRoute(
      path: '/deeplink/post/:id',
      builder: (context, state) {
        final postId = int.parse(state.pathParameters['id']!);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.go('/post/$postId');
        });
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    ),
    GoRoute(
      path: '/business/:id',
      builder: (context, state) {
        final businessId = int.parse(state.pathParameters['id']!);
        return BusinessDetailScreen(businessId: businessId);
      },
    ),
    GoRoute(
      path: '/community/:id',
      builder: (context, state) {
        final communityId = int.parse(state.pathParameters['id']!);
        return CommunityPostsScreen(communityId: communityId);
      },
    ),

    ShellRoute(
      builder: (context, state, child) {
        return MainLayout(child: child);
      },
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const PostsScreen(),
        ),
        GoRoute(path: '/me', builder: (context, state) => const MeScreen()),
        GoRoute(
          path: '/newcomers',
          builder: (context, state) => const NewcomersScreen(),
        ),
        GoRoute(
          path: '/chats',
          builder: (context, state) => const ChatsScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);

Future<void> _saveOAuthTokens(
  String accessToken,
  String refreshToken,
  String? userId,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('auth_token', accessToken);
  await prefs.setString('refresh_token', refreshToken);
  if (userId != null) {
    await prefs.setString('device_id', userId);
  }
}

class MainLayout extends StatelessWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  int _getIndex(String location) {
    if (location.startsWith('/me')) return 1;
    if (location.startsWith('/newcomers')) return 2;
    if (location.startsWith('/chats')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _getIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.yellowAccent,
        unselectedItemColor: AppColors.grey,
        currentIndex: currentIndex,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/home');
              break;
            case 1:
              context.go('/me');
              break;
            case 2:
              context.go('/newcomers');
              break;
            case 3:
              context.go('/chats');
              break;
            case 4:
              context.go('/settings');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          BottomNavigationBarItem(icon: Icon(Icons.business), label: "New"),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: "Chats"),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Settings",
          ),
        ],
      ),
    );
  }
}
