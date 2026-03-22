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
        backgroundColor: AppColors.surface,
        title: Text(
          'Feed',
          style: TextStyle(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: AppColors.onSurfaceVariant),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: Icon(Icons.add_circle, color: AppColors.primary),
            onPressed: () => context.push('/create-post'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.onSurfaceVariant,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: _communityCount >= 5 ? 'For You' : 'All'),
                const Tab(text: 'Popular'),
              ],
            ),
          ),
        ),
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
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error: $_error',
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPosts,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (posts.isEmpty) {
      return Center(
        child: Text(
          'No posts yet. Be the first to create one!',
          style: TextStyle(color: AppColors.onSurfaceVariant),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPosts,
      displacement: 50,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          final postId = post['post_id'] ?? post['id'];
          if (postId == null) return const SizedBox.shrink();
          final stats = post['stats'] as Map<String, dynamic>?;
          final median = post['median'] != null
              ? (post['median'] as num).toDouble()
              : (stats?['median'] ?? 0).toDouble();
          final voteCount = post['n_votes'] ?? stats?['amount'] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
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
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Vote on this post',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: wouldPayController,
                decoration: InputDecoration(
                  labelText: 'How much would you pay?',
                  prefixIcon: Icon(
                    Icons.attach_money,
                    color: AppColors.onSurfaceVariant,
                  ),
                  suffixIcon: Icon(
                    Icons.monetization_on,
                    color: AppColors.secondary,
                  ),
                ),
                keyboardType: TextInputType.number,
                style: TextStyle(color: AppColors.onSurface),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: competitionController,
                decoration: InputDecoration(
                  labelText: 'Competition (optional)',
                  prefixIcon: Icon(
                    Icons.group,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                style: TextStyle(color: AppColors.onSurface),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: problemsController,
                decoration: InputDecoration(
                  labelText: 'Problems (optional)',
                  prefixIcon: Icon(
                    Icons.warning,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                style: TextStyle(color: AppColors.onSurface),
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
                            SnackBar(
                              content: const Text(
                                'Please enter a valid amount',
                              ),
                              backgroundColor: AppColors.error,
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
                              SnackBar(content: const Text('Vote submitted!')),
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
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: isLoading
                    ? CircularProgressIndicator(color: AppColors.onPrimary)
                    : const Text('Submit Vote'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
