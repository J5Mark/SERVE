import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app/api.dart';
import 'package:app/widgets.dart';

class CommunityPostsScreen extends StatefulWidget {
  final int communityId;

  const CommunityPostsScreen({super.key, required this.communityId});

  @override
  State<CommunityPostsScreen> createState() => _CommunityPostsScreenState();
}

class _CommunityPostsScreenState extends State<CommunityPostsScreen> {
  Map<String, dynamic>? _community;
  List<dynamic> _posts = [];
  bool _isLoading = true;
  String? _error;
  String _sorting = 'popular';

  @override
  void initState() {
    super.initState();
    _loadCommunity();
    _loadPosts();
  }

  Future<void> _loadCommunity() async {
    try {
      final community = await Api.getCommunity(widget.communityId);
      if (mounted) {
        setState(() => _community = community);
      }
    } catch (e) {
      // Community load error - not critical
    }
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    try {
      final posts = await Api.getCommunityPosts(
        communityId: widget.communityId,
        n: 20,
        offset: 0,
        sorting: _sorting,
      );
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

  Future<void> _joinCommunity() async {
    try {
      await Api.joinCommunity(widget.communityId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Joined community!'),
            backgroundColor: AppColors.brightGreen,
          ),
        );
        _loadCommunity();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final isModerator = _community?['is_moderator'] ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(_community?['name'] ?? 'Community'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (isModerator)
            IconButton(
              icon: const Icon(Icons.shield),
              onPressed: () => _showModeratorMenu(context),
              tooltip: 'Moderator Menu',
            ),
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: _joinCommunity,
            tooltip: 'Join Community',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/create-post'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'popular', label: Text('!!')),
                ButtonSegment(value: 'new', label: Text('New')),
                ButtonSegment(value: 'med_asc', label: Text('Med ↑')),
                ButtonSegment(value: 'med_desc', label: Text('Med ↓')),
              ],
              selected: {_sorting},
              onSelectionChanged: (selection) {
                setState(() => _sorting = selection.first);
                _loadPosts();
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.brightGreen;
                  }
                  return AppColors.darkGreen;
                }),
              ),
            ),
          ),
          Expanded(child: _buildPostList()),
        ],
      ),
    );
  }

  void _showModeratorMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.primaryBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Moderator Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: AppColors.brightGreen),
              title: const Text(
                'Edit Community',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to edit community screen
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.person_add,
                color: AppColors.brightGreen,
              ),
              title: const Text(
                'Manage Moderators',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to manage moderators screen
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPostList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
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
    final isModerator = _community?['is_moderator'] ?? false;
    return RefreshIndicator(
      onRefresh: _loadPosts,
      displacement: 50,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          final postId = post['post_id'];
          final median = (post['median'] ?? 0).toDouble();
          final voteCount = post['n_votes'] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _PostCard(
              post: post,
              median: median,
              voteCount: voteCount,
              isModerator: isModerator,
              onTap: () => context.push('/post/$postId'),
              onVote: () => _showVoteSheet(postId),
              onDelete: isModerator ? () => _deletePost(postId) : null,
            ),
          );
        },
      ),
    );
  }

  Future<void> _deletePost(int postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkGreen,
        title: const Text('Delete Post', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
          style: TextStyle(color: AppColors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await Api.deletePost(postId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post deleted'),
            backgroundColor: AppColors.brightGreen,
          ),
        );
        _loadPosts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _PostCard extends StatelessWidget {
  final dynamic post;
  final double median;
  final int voteCount;
  final bool isModerator;
  final VoidCallback? onTap;
  final VoidCallback? onVote;
  final VoidCallback? onDelete;

  const _PostCard({
    required this.post,
    required this.median,
    required this.voteCount,
    required this.isModerator,
    this.onTap,
    this.onVote,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      post['name'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (isModerator && onDelete != null)
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                        size: 20,
                      ),
                      onPressed: onDelete,
                      tooltip: 'Delete Post',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                post['contents'] ?? '',
                style: const TextStyle(color: AppColors.grey, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.attach_money,
                    size: 16,
                    color: AppColors.yellowAccent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '\$${median.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppColors.yellowAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (voteCount > 0) ...[
                    Icon(Icons.how_to_vote, size: 14, color: AppColors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '$voteCount',
                      style: TextStyle(color: AppColors.grey, fontSize: 13),
                    ),
                  ],
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.how_to_vote,
                      color: AppColors.brightGreen,
                      size: 20,
                    ),
                    onPressed: onVote,
                    tooltip: 'Vote',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
