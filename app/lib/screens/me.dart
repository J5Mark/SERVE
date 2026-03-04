import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app/api.dart';
import 'package:app/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MeScreen extends StatefulWidget {
  const MeScreen({super.key});

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final deviceId = await Api.getDeviceId();
      if (deviceId == null) {
        if (mounted) {
          setState(() {
            _error = 'Not logged in';
            _isLoading = false;
          });
        }
        return;
      }

      final user = await Api.getUser(deviceId);
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
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

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

    if (_user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Not registered'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.push('/register'),
              child: const Text('Register'),
            ),
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
            ElevatedButton(
              onPressed: () => context.push('/register'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brightGreen,
              ),
              child: const Text('Complete Profile'),
            ),
          ],
        ),
      );
    }
    final entrep = _user!['entrep'] ?? false;
    final createdAt = _user!['created_at'] ?? '';
    final communities = _user!['communities'] as List? ?? [];

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

    return RefreshIndicator(
      onRefresh: _loadUser,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfileWidget(
              firstName: firstName,
              lastName: lastName,
              username: username,
              roles: roles,
              memberSince: memberSince,
              posts: [],
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
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('View Newcomers'),
              onTap: () {
                Navigator.pop(context);
                context.push('/newcomers');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    await prefs.remove('device_id');
    if (mounted) {
      context.go('/init');
    }
  }
}
