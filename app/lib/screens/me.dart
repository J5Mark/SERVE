import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app/api.dart';
import 'package:app/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class MeScreen extends StatefulWidget {
  const MeScreen({super.key});

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  String? _error;
  List<dynamic> _discoverCommunities = [];
  bool _isLoadingDiscover = false;
  String _discoverSorting = 'popular';
  bool _hasGoogleIntegration = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _checkGoogleIntegration();
  }

  Future<void> _checkGoogleIntegration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return;

      final user = await Api.getUser();
      final integrations = user['integrations'] as List? ?? [];
      final hasGoogle = integrations.any((i) => i['provider'] == 'google');
      if (mounted) {
        setState(() {
          _hasGoogleIntegration = hasGoogle;
        });
      }
    } catch (e) {
      print('Error checking Google integration: $e');
    }
  }

  Future<void> _linkGoogleAccount() async {
    try {
      final anonymousId = await Api.getAnonymousId();

      final url = Uri.parse(
        'https://serveyourcommunity.ftp.sh/api/auth/google/start?anonymous_id=$anonymousId',
      );
      // Use in-app webview for better UX, falls back to external browser
      final result = await launchUrl(url, mode: LaunchMode.platformDefault);
      if (!result && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch Google OAuth'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadUser() async {
    try {
      final hasToken = await Api.hasToken();
      if (!hasToken) {
        if (mounted) {
          setState(() {
            _error = 'Not logged in';
            _isLoading = false;
          });
        }
        return;
      }

      final user = await Api.getUser();
      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadDiscoverCommunities() async {
    setState(() => _isLoadingDiscover = true);
    try {
      final communities = await Api.discoverCommunities(
        n: 10,
        offset: 0,
        sorting: _discoverSorting,
      );
      if (mounted) {
        setState(() {
          _discoverCommunities = communities;
          _isLoadingDiscover = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDiscover = false);
      }
    }
  }

  Future<void> _joinCommunity(int communityId) async {
    try {
      await Api.joinCommunity(communityId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Joined community!'),
            backgroundColor: AppColors.brightGreen,
          ),
        );
        _loadUser();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showActionSheet(context),
        backgroundColor: AppColors.brightGreen,
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // If user is not registered (404), show complete profile options
    if (_user == null) {
      print(
        'ME_SCREEN: _user is null, error = $_error, showing complete profile screen',
      );
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Complete your profile',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Register or sign in with Google'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/register'),
              icon: const Icon(Icons.email),
              label: const Text('Register'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brightGreen,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _linkGoogleAccount,
              icon: const Icon(Icons.g_mobiledata, size: 24),
              label: const Text('Continue with Google'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Show actual errors for other cases
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadUser, child: const Text('Retry')),
          ],
        ),
      );
    }

    final firstName = _user!['first_name'] ?? '';
    final lastName = _user!['last_name'] ?? '';
    final username = _user!['username'] ?? '';

    if (firstName.isEmpty && username.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_outline, size: 64, color: AppColors.grey),
            const SizedBox(height: 16),
            const Text(
              'Complete your profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Set up your username and name to get started',
              style: TextStyle(color: AppColors.grey),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => context.push('/register'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brightGreen,
                    ),
                    child: const Text('Register'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _linkGoogleAccount(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                    ),
                    icon: Icon(Icons.g_mobiledata, color: Colors.black),
                    label: Text(
                      'Google',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    final entrep = _user!['entrep'] ?? false;
    final createdAt = _user!['created_at'] ?? '';
    final communities = _user!['communities'] as List? ?? [];
    final businesses = _user!['businesses'] as List? ?? [];
    final posts = _user!['posts'] as List? ?? [];

    List<String> roles = [];
    if (entrep) roles.add('Entrepreneur');

    String memberSince = '';
    if (createdAt.isNotEmpty) {
      try {
        final date = DateTime.parse(createdAt);
        memberSince = '${date.month}/${date.year}';
      } catch (_) {
        memberSince = createdAt;
      }
    }

    final userId = _user!['id'] as int;

    return RefreshIndicator(
      onRefresh: _loadUser,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => _showEditProfileDialog(userId),
              child: ProfileWidgetLight(
                firstName: firstName,
                lastName: lastName,
                username: username,
                roles: roles,
                memberSince: memberSince,
                editable: true,
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.drive_file_move,
                  color: AppColors.brightGreen,
                ),
                title: Text(
                  _hasGoogleIntegration
                      ? 'Google Connected'
                      : 'Link Google Account',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  _hasGoogleIntegration
                      ? 'Your Google account is connected'
                      : 'Connect for Drive access',
                  style: TextStyle(color: AppColors.grey),
                ),
                trailing: _hasGoogleIntegration
                    ? Icon(Icons.check_circle, color: AppColors.brightGreen)
                    : Icon(Icons.chevron_right, color: AppColors.grey),
                onTap: () => _linkGoogleAccount(),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your Communities',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            if (communities.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'No communities yet',
                        style: TextStyle(color: AppColors.grey),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => context.push('/create-community'),
                        child: const Text('Create Community'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...communities.map(
                (c) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(
                      Icons.groups,
                      color: AppColors.brightGreen,
                    ),
                    title: Text(
                      c['name'] ?? '',
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.grey,
                    ),
                    onTap: () => context.push('/community/${c['id']}'),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Discover Communities',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _loadDiscoverCommunities();
                    _showDiscoverCommunitiesSheet(context);
                  },
                  child: const Text('See All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Find new communities',
                      style: TextStyle(color: AppColors.grey),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        _loadDiscoverCommunities();
                        _showDiscoverCommunitiesSheet(context);
                      },
                      child: const Text('Discover'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your Businesses',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            if (businesses.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'No businesses yet',
                        style: TextStyle(color: AppColors.grey),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => context.push('/create-business'),
                        child: const Text('Create Business'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...businesses.map(
                (b) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(
                      Icons.business,
                      color: AppColors.brightGreen,
                    ),
                    title: Text(
                      b['name'] ?? '',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      b['bio'] ?? '',
                      style: TextStyle(color: AppColors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.grey,
                    ),
                    onTap: () => context.push('/business/${b['id']}'),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              'Your Posts',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            if (posts.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'No posts yet',
                        style: TextStyle(color: AppColors.grey),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => context.push('/create-post'),
                        child: const Text('Create Post'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...posts.map(
                (p) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(
                      Icons.article,
                      color: AppColors.brightGreen,
                    ),
                    title: Text(
                      p['name'] ?? '',
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.grey,
                    ),
                    onTap: () => context.push('/post/${p['id']}'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.post_add),
              title: const Text('Create Post'),
              onTap: () {
                Navigator.pop(context);
                context.push('/create-post');
              },
            ),
            if (_user != null && (_user!['entrep'] == true))
              ListTile(
                leading: const Icon(Icons.business),
                title: const Text('Create Business'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/create-business');
                },
              ),
            ListTile(
              leading: const Icon(Icons.group_add),
              title: const Text('Create Community'),
              onTap: () {
                Navigator.pop(context);
                context.push('/create-community');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDiscoverCommunitiesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.primaryBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Discover Communities',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'popular', label: Text('Popular')),
                  ButtonSegment(value: 'new', label: Text('New')),
                  ButtonSegment(value: 'relevant', label: Text('Relevant')),
                ],
                selected: {_discoverSorting},
                onSelectionChanged: (selection) {
                  setState(() => _discoverSorting = selection.first);
                  _loadDiscoverCommunities();
                },
              ),
            ),
            const SizedBox(height: 8),
            const Divider(color: AppColors.grey, height: 1),
            Expanded(
              child: _isLoadingDiscover
                  ? const Center(child: CircularProgressIndicator())
                  : _discoverCommunities.isEmpty
                  ? const Center(
                      child: Text(
                        'No communities found',
                        style: TextStyle(color: AppColors.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _discoverCommunities.length,
                      itemBuilder: (context, index) {
                        final community = _discoverCommunities[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(
                              Icons.groups,
                              color: AppColors.brightGreen,
                            ),
                            title: Text(
                              community['name'] ?? '',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              community['description'] ?? '',
                              style: TextStyle(color: AppColors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: ElevatedButton(
                              onPressed: () {
                                _joinCommunity(community['id']);
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brightGreen,
                              ),
                              child: const Text('Join'),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/community/${community['id']}');
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(int userId) {
    final usernameController = TextEditingController(
      text: _user!['username'] ?? '',
    );
    final firstNameController = TextEditingController(
      text: _user!['first_name'] ?? '',
    );
    final lastNameController = TextEditingController(
      text: _user!['last_name'] ?? '',
    );
    final emailController = TextEditingController(text: _user!['email'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.primaryBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          bool isLoading = false;
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text(
                      'Edit Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'First Name',
                    prefixIcon: Icon(Icons.badge),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Last Name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          setSheetState(() => isLoading = true);
                          try {
                            await Api.updateUser(
                              userId,
                              username: usernameController.text.isEmpty
                                  ? null
                                  : usernameController.text,
                              firstName: firstNameController.text.isEmpty
                                  ? null
                                  : firstNameController.text,
                              lastName: lastNameController.text.isEmpty
                                  ? null
                                  : lastNameController.text,
                              email: emailController.text.isEmpty
                                  ? null
                                  : emailController.text,
                            );
                            if (context.mounted) {
                              Navigator.pop(context);
                              _loadUser();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profile updated!'),
                                  backgroundColor: AppColors.brightGreen,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setSheetState(() => isLoading = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brightGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Save'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    if (mounted) {
      context.go('/init');
    }
  }
}
