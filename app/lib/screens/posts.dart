import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app/api.dart';
import 'package:app/widgets.dart';

class PostsScreen extends StatefulWidget {
  const PostsScreen({super.key});

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _forYouPosts = [];
  List<dynamic> _popularPosts = [];
  bool _isLoading = true;
  String? _error;
  int _communityCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPosts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    try {
      final deviceId = await Api.getDeviceId();
      if (deviceId == null) {
        final popular = await Api.getPopularPosts(20, 0);
        if (mounted) {
          setState(() {
            _popularPosts = popular;
            _isLoading = false;
          });
        }
        return;
      }

      final user = await Api.getUser(deviceId);
      final communities = user['communities'] as List? ?? [];
      _communityCount = communities.length;

      final results = await Future.wait([
        _communityCount >= 5 ? Api.getPosts(20, 0) : Api.getPopularPosts(20, 0),
        Api.getPopularPosts(20, 0),
      ]);

      if (mounted) {
        setState(() {
          _forYouPosts = results[0];
          _popularPosts = results[1];
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
        title: const Text('Posts'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: _communityCount >= 5 ? 'For You' : 'Popular'),
            const Tab(text: 'Popular'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/create-post'),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPostList(_communityCount >= 5 ? _forYouPosts : _popularPosts),
          _buildPostList(_popularPosts),
        ],
      ),
    );
  }

  Widget _buildPostList(List<dynamic> posts) {
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
            ElevatedButton(onPressed: _loadPosts, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (posts.isEmpty) {
      return const Center(
        child: Text('No posts yet. Be the first to create one!'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          final postId = post['id'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: InkWell(
              onTap: () => context.push('/post/$postId'),
              child: PostWidget(
                title: post['name'] ?? '',
                content: post['contents'] ?? '',
                average: (post['stats']?['mean'] ?? 0).toDouble(),
                median: (post['stats']?['median'] ?? 0).toDouble(),
                min: (post['stats']?['min'] ?? 0).toDouble(),
                max: (post['stats']?['max'] ?? 0).toDouble(),
                voteCount: post['stats']?['amount'] ?? 0,
              ),
            ),
          );
        },
      ),
    );
  }
}
