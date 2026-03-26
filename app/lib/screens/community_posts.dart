import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app/api.dart';
import 'package:app/widgets.dart';
import 'package:share_plus/share_plus.dart';

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

  int _offset = 0;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadCommunity();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final morePosts = await Api.getCommunityPosts(
        communityId: widget.communityId,
        n: 20,
        offset: _offset + 20,
        sorting: _sorting,
      );

      if (mounted) {
        setState(() {
          _posts.addAll(morePosts);
          _offset += 20;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
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
    _offset = 0;
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

  Future<void> _shareCommunity() async {
    final communityName = _community?['name'] ?? 'this community';
    final webUrl =
        'https://serveyourcommunity.ftp.sh/#/community/${widget.communityId}';

    await Share.share(
      'Join the $communityName community on SERVE!\n\n$webUrl',
      subject: communityName,
    );
  }

  Future<void> _joinCommunity() async {
    try {
      await Api.joinCommunity(widget.communityId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Joined community!'),
            backgroundColor: AppColors.primary,
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

  Future<void> _leaveCommunity() async {
    try {
      await Api.leaveCommunity(widget.communityId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Left community'),
            backgroundColor: AppColors.primary,
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

  Widget _buildJoinButton(bool isMember, bool isModerator) {
    if (isModerator) {
      return const SizedBox.shrink();
    }
    if (isMember) {
      return OutlinedButton.icon(
        onPressed: _leaveCommunity,
        icon: const Icon(Icons.check, size: 16),
        label: const Text('Joined'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: _joinCommunity,
      icon: const Icon(Icons.add, size: 16),
      label: const Text('Join'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.primaryBlack,
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }

  String _getSubredditName(String redditLink) {
    // Handle various reddit link formats: reddit.com/r/name, r/name, reddit.com/r/name/
    if (redditLink.contains('reddit.com/r/')) {
      final parts = redditLink.split('reddit.com/r/');
      if (parts.length > 1) {
        return parts[1].replaceAll('/', '');
      }
    }
    if (redditLink.startsWith('r/')) {
      return redditLink.substring(2);
    }
    return redditLink;
  }

  void _showVoteSheet(int postId) {
    final wouldPayController = TextEditingController();
    final competitionController = TextEditingController();
    final problemsController = TextEditingController();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
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
                  backgroundColor: AppColors.primary,
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
    final isMember = _community?['is_member'] ?? false;
    final communityName = _community?['name'] ?? 'Community';
    final description = _community?['description'] ?? '';
    final participants = _community?['participants'] ?? 0;
    final redditLink = _community?['reddit_link'] as String?;
    final redditName = redditLink != null && redditLink.isNotEmpty
        ? _getSubredditName(redditLink)
        : null;
    final redditSubscribers = _community?['reddit_subscribers'] as int?;
    final redditDescription = _community?['reddit_description'] as String?;
    final communityAvatarUrl = Api.getCommunityAvatarUrl(widget.communityId);

    return Scaffold(
      appBar: AppBar(
        title: Text(communityName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareCommunity(),
            tooltip: 'Share Community',
          ),
          if (isModerator)
            IconButton(
              icon: const Icon(Icons.shield),
              onPressed: () => _showModeratorMenu(context),
              tooltip: 'Moderator Menu',
            ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/create-post'),
            tooltip: 'Create Post',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surfaceContainer,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          communityAvatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.groups,
                            color: AppColors.primary,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            communityName,
                            style: TextStyle(
                              color: AppColors.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 14,
                                color: AppColors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$participants',
                                style: TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              if (redditName != null) ...[
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.forum,
                                  size: 14,
                                  color: AppColors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'r/$redditName${redditSubscribers != null ? ' ($redditSubscribers)' : ''}',
                                  style: TextStyle(
                                    color: AppColors.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    _buildJoinButton(isMember, isModerator),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
                if (redditDescription != null &&
                    redditDescription.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    redditDescription,
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (isModerator) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'You moderate this community',
                      style: TextStyle(color: AppColors.primary, fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'popular', label: Text('Popular')),
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
                    return AppColors.primary;
                  }
                  return AppColors.surfaceContainer;
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
      backgroundColor: AppColors.surface,
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
                color: AppColors.onSurfaceVariant,
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
              leading: const Icon(Icons.edit, color: AppColors.primary),
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
              leading: const Icon(Icons.person_add, color: AppColors.primary),
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
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _posts.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
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
        backgroundColor: AppColors.surfaceContainer,
        title: const Text('Delete Post', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
          style: TextStyle(color: AppColors.onSurfaceVariant),
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
            backgroundColor: AppColors.primary,
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
                    child: SelectableText(
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
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 14,
                ),
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
                    Icon(
                      Icons.how_to_vote,
                      size: 14,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$voteCount',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.how_to_vote,
                      color: AppColors.primary,
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
