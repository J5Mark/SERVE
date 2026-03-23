import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/auth_provider.dart';
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
import 'package:app/screens/my_analyses.dart';
import 'package:app/screens/view_analysis.dart';
import 'package:app/widgets.dart';

AuthStateNotifier? authState;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final isDarker = prefs.getBool('darker_theme') ?? false;
  AppTheme.setDarkerMode(isDarker);

  print('MAIN: Starting app...');
  print('MAIN: Current URL = ${Uri.base}');
  print('MAIN: Current URL query = ${Uri.base.query}');
  print('MAIN: Current URL fragment = ${Uri.base.fragment}');
  print('MAIN: Query params = ${Uri.base.queryParameters}');

  // Check for OAuth tokens in the URL BEFORE initializing app
  final currentUri = Uri.base;
  final accessToken = currentUri.queryParameters['access_token'];
  final refreshToken = currentUri.queryParameters['refresh_token'];
  final userId = currentUri.queryParameters['user_id'];

  print(
    'MAIN: OAuth tokens in URL? access=${accessToken != null}, refresh=${refreshToken != null}',
  );

  if (accessToken != null && refreshToken != null) {
    print('MAIN: Found OAuth tokens in URL, saving them...');
    print(
      'MAIN: access_token (first 50 chars) = ${accessToken.substring(0, 50)}...',
    );
    print('MAIN: user_id = $userId');
    // Initialize auth state
    final authNotifier = AuthStateNotifier();
    await authNotifier.initialize();
    authState = authNotifier;

    // Save the tokens immediately
    await authNotifier.saveTokensFromUrl(accessToken, refreshToken, userId);
    print('MAIN: OAuth tokens saved from URL!');
  } else {
    print('MAIN: No OAuth tokens found, doing normal init');
    final authNotifier = AuthStateNotifier();
    await authNotifier.initialize();
    authState = authNotifier;
  }

  runApp(const MyApp());
}

Future<void> _handleOAuthCallback() async {
  // This is a simple check - in practice we'd use platform channels
  // For now, the router redirect will handle tokens
}

Future<void> saveOAuthTokens(
  String accessToken,
  String refreshToken,
  String? userId,
) async {
  print('saveOAuthTokens: START');
  if (authState != null) {
    print('saveOAuthTokens: authState exists, calling saveTokensFromUrl');
    await authState!.saveTokensFromUrl(accessToken, refreshToken, userId);
    print('saveOAuthTokens: DONE');
  } else {
    print('saveOAuthTokens: ABORTED - authState is null!');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    AppTheme.listener.addListener(_handleThemeChange);
  }

  void _handleThemeChange() {
    setState(() {});
  }

  @override
  void dispose() {
    AppTheme.listener.removeListener(_handleThemeChange);
    super.dispose();
  }

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
  initialExtra: null,

  redirect: (BuildContext context, GoRouterState state) async {
    // Wait for auth to initialize
    if (authState == null || authState!.state == AuthState.initial) {
      return null;
    }

    final isOnInit = state.matchedLocation == '/init';

    // If on init screen, always allow going to home (browse without auth)
    if (isOnInit) {
      return '/home';
    }

    return null;
  },

  routes: [
    GoRoute(
      path: '/auth',
      builder: (context, state) {
        // Handle deep link from Google OAuth: https://serveyourcommunity.ftp.sh/auth?access_token=xxx&refresh_token=xxx&user_id=xxx
        final uri = state.uri;
        final accessToken = uri.queryParameters['access_token'];
        final refreshToken = uri.queryParameters['refresh_token'];
        final userId = uri.queryParameters['user_id'];

        print(
          'ROUTE /auth: access_token=${accessToken != null ? 'found' : 'null'}',
        );
        print(
          'ROUTE /auth: refreshToken=${refreshToken != null ? 'found' : 'null'}',
        );
        print('ROUTE /auth: userId=$userId');

        if (accessToken != null && refreshToken != null) {
          print('ROUTE /auth: Saving tokens and redirecting to /home');
          // Save tokens and redirect to home
          _saveOAuthTokens(accessToken, refreshToken, userId).then((_) {
            print('ROUTE /auth: Tokens saved, redirecting to /home');
            context.go('/home');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
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
          _saveOAuthTokens(accessToken, refreshToken, userId).then((_) {
            context.go('/home');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
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
      path: '/login',
      builder: (context, state) => const RegisterScreen(showLoginTab: true),
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
          path: '/auth',
          builder: (context, state) {
            // Handle deep link from Google OAuth
            // Extract tokens from state.uri which should have query params
            final uri = state.uri;
            final accessToken = uri.queryParameters['access_token'];
            final refreshToken = uri.queryParameters['refresh_token'];
            final userId = uri.queryParameters['user_id'];

            print(
              'ROUTE /auth: access_token=${accessToken != null ? 'found' : 'null'}',
            );
            print(
              'ROUTE /auth: refreshToken=${refreshToken != null ? 'found' : 'null'}',
            );
            print('ROUTE /auth: userId=$userId');
            print('ROUTE /auth: state.uri=$uri');
            print('ROUTE /auth: Uri.base=${Uri.base}');

            if (accessToken != null && refreshToken != null) {
              print('ROUTE /auth: Saving tokens and redirecting to /home');
              // Save tokens and redirect to home
              _saveOAuthTokens(accessToken, refreshToken, userId).then((_) {
                print('ROUTE /auth: Tokens saved, redirecting to /home');
                context.go('/home');
              });
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            print('ROUTE /auth: No tokens found, showing loading screen');
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          },
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
        GoRoute(path: '/', builder: (context, state) => const PostsScreen()),
        GoRoute(
          path: '/home',
          builder: (context, state) => const PostsScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/chats',
          builder: (context, state) => const ChatsScreen(),
        ),
        GoRoute(
          path: '/my-analyses',
          builder: (context, state) => const MyAnalysesScreen(),
        ),
        GoRoute(
          path: '/analysis/:postId',
          builder: (context, state) {
            final postId = int.parse(state.pathParameters['postId']!);
            return ViewAnalysisScreen(postId: postId);
          },
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
  await authState?.setAuthenticated(accessToken, refreshToken, userId: userId);
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.surfaceContainer, AppColors.surface],
          ),
          border: Border(
            top: BorderSide(
              color: AppColors.outlineVariant.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Feed',
                  isSelected: currentIndex == 0,
                  onTap: () => context.go('/home'),
                ),
                _NavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profile',
                  isSelected: currentIndex == 1,
                  onTap: () => context.go('/me'),
                ),
                _NavItem(
                  icon: Icons.business_outlined,
                  activeIcon: Icons.business,
                  label: 'New',
                  isSelected: currentIndex == 2,
                  onTap: () => context.go('/newcomers'),
                ),
                _NavItem(
                  icon: Icons.chat_bubble_outline,
                  activeIcon: Icons.chat_bubble,
                  label: 'Chats',
                  isSelected: currentIndex == 3,
                  onTap: () => context.go('/chats'),
                ),
                _NavItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  label: 'Settings',
                  isSelected: currentIndex == 4,
                  onTap: () => context.go('/settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: isSelected
              ? BoxDecoration(
                  color: AppColors.surfaceBright.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
