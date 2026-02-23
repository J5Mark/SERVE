import 'package:flutter/material.dart';
import 'package:app/api.dart';
import 'package:app/widgets.dart';

class PostsScreen extends StatefulWidget {
  const PostsScreen({super.key});

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  List<dynamic> _posts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    try {
      final hasToken = await Api.hasToken();
      final posts = hasToken
          ? await Api.getPosts()
          : await Api.getPopularPosts();
      if (mounted) {
        setState(() {
          _posts = posts;
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
        title: const Text('Community Posts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Navigate to create post
            },
          ),
        ],
      ),
      body: _buildBody(),
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
            ElevatedButton(onPressed: _loadPosts, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_posts.isEmpty) {
      return const Center(
        child: Text('No posts yet. Be the first to create one!'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: PostWidget(
              title: post['title'] ?? '',
              content: post['content'] ?? post['description'] ?? '',
              average: (post['average'] ?? post['willingness_to_pay_avg'] ?? 0)
                  .toDouble(),
              median: (post['median'] ?? post['willingness_to_pay_median'] ?? 0)
                  .toDouble(),
              min: (post['min'] ?? post['willingness_to_pay_min'] ?? 0)
                  .toDouble(),
              max: (post['max'] ?? post['willingness_to_pay_max'] ?? 0)
                  .toDouble(),
              voteCount: post['votes'] ?? post['vote_count'] ?? 0,
            ),
          );
        },
      ),
    );
  }
}
