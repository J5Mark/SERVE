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
    return Scaffold(
      appBar: AppBar(
        title: Text(_community?['name'] ?? 'Community'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
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
                ButtonSegment(value: 'popular', label: Text('Popular')),
                ButtonSegment(value: 'new', label: Text('New')),
                ButtonSegment(value: 'relevant', label: Text('Relevant')),
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
            child: InkWell(
              onTap: () => context.push('/post/$postId'),
              child: PostWidget(
                title: post['name'] ?? '',
                content: post['contents'] ?? '',
                median: median,
                voteCount: voteCount,
                onVote: () => _showVoteSheet(postId),
                compact: true,
              ),
            ),
          );
        },
      ),
    );
  }
}
