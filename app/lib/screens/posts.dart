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
      final hasToken = await Api.hasToken();

      dynamic user;
      if (hasToken) {
        try {
          user = await Api.getUser();
        } catch (e) {
          user = null;
        }
      } else {
        user = null;
      }

      final communities = user?['communities'] as List? ?? [];
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
            Tab(text: _communityCount >= 5 ? 'For You' : 'All'),
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
      displacement: 50,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          // Handle both old format (id) and new format (post_id)
          final postId = post['post_id'] ?? post['id'];
          if (postId == null) return const SizedBox.shrink();
          // Handle both old format (stats) and new format (median, n_votes)
          final stats = post['stats'] as Map<String, dynamic>?;
          final median = post['median'] != null
              ? (post['median'] as num).toDouble()
              : (stats?['median'] ?? 0).toDouble();
          final voteCount = post['n_votes'] ?? stats?['amount'] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: InkWell(
              onTap: () => context.push('/post/$postId'),
              child: PostWidget(
                title: post['name'] ?? '',
                content: post['contents'] ?? '',
                median: median,
                voteCount: voteCount,
                communityName: post['community_name'],
                onVote: () => _showVoteSheet(postId),
                compact: true,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showVoteSheet(int postId) {
    final wouldPayController = TextEditingController();
    final competitionController = TextEditingController();
    final problemsController = TextEditingController();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.primaryBlack,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
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
              const Text(
                'Vote on this post',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: wouldPayController,
                decoration: const InputDecoration(
                  labelText: 'How much would you pay?',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: competitionController,
                decoration: const InputDecoration(
                  labelText: 'Competition (optional)',
                  prefixIcon: Icon(Icons.group),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: problemsController,
                decoration: const InputDecoration(
                  labelText: 'Problems (optional)',
                  prefixIcon: Icon(Icons.warning),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final wouldPay = double.tryParse(
                          wouldPayController.text,
                        );
                        if (wouldPay == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid amount'),
                            ),
                          );
                          return;
                        }
                        setSheetState(() => isLoading = true);
                        try {
                          await Api.voteOnPost(
                            postId: postId,
                            wouldPay: wouldPay,
                            competition: competitionController.text.isEmpty
                                ? null
                                : competitionController.text,
                            problems: problemsController.text.isEmpty
                                ? null
                                : problemsController.text,
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Vote submitted!')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
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
                    : const Text('Submit Vote'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
