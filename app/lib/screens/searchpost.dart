import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app/api.dart';
import 'package:app/widgets.dart';

class SearchPostScreen extends StatefulWidget {
  const SearchPostScreen({super.key});

  @override
  State<SearchPostScreen> createState() => _SearchPostScreenState();
}

class _SearchPostScreenState extends State<SearchPostScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _postResults = [];
  List<dynamic> _communityResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _error;
  late TabController _tabController;
  bool _searchCommunities = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _searchCommunities = _tabController.index == 1;
      });
      if (_hasSearched) {
        _search();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _error = null;
    });

    try {
      if (_searchCommunities) {
        final results = await Api.searchCommunities(query, 20);
        if (mounted) {
          setState(() {
            _communityResults = results;
            _isLoading = false;
          });
        }
      } else {
        final results = await Api.searchPosts(query, 20);
        if (mounted) {
          setState(() {
            _postResults = results;
            _isLoading = false;
          });
        }
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

  void _toggleCommunitySearch() {
    setState(() {
      _searchCommunities = !_searchCommunities;
      _tabController.index = _searchCommunities ? 1 : 0;
    });
    if (_hasSearched) {
      _search();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Posts'),
            Tab(text: 'Communities'),
          ],
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.onSurfaceVariant,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _searchCommunities
                          ? 'Search communities...'
                          : 'Search posts...',
                      hintStyle: const TextStyle(color: AppColors.onSurfaceVariant),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.onSurfaceVariant,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.onSurfaceVariant),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _postResults = [];
                            _communityResults = [];
                            _hasSearched = false;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: AppColors.darkGreen,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _toggleCommunitySearch,
                  icon: Icon(
                    _searchCommunities ? Icons.groups : Icons.article,
                    color: _searchCommunities
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                  ),
                  tooltip: _searchCommunities
                      ? 'Search Posts'
                      : 'Search Communities',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildPostsTab(), _buildCommunitiesTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsTab() {
    if (_isLoading && !_searchCommunities) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && !_searchCommunities) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _search, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return const Center(
        child: Text(
          'Enter a search query to find posts',
          style: TextStyle(color: AppColors.onSurfaceVariant),
        ),
      );
    }

    if (_postResults.isEmpty) {
      return const Center(
        child: Text('No posts found', style: TextStyle(color: AppColors.onSurfaceVariant)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _postResults.length,
      itemBuilder: (context, index) {
        final post = _postResults[index];
        final median = (post['median'] ?? 0).toDouble();
        final voteCount = post['n_votes'] ?? 0;
        final postId = post['post_id'];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: PostWidget(
            title: post['name'] ?? '',
            content: post['contents'] ?? '',
            median: median,
            voteCount: voteCount,
            onTap: () => context.push('/post/$postId'),
            compact: true,
          ),
        );
      },
    );
  }

  Widget _buildCommunitiesTab() {
    if (_isLoading && _searchCommunities) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _searchCommunities) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _search, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return const Center(
        child: Text(
          'Enter a search query to find communities',
          style: TextStyle(color: AppColors.onSurfaceVariant),
        ),
      );
    }

    if (_communityResults.isEmpty) {
      return const Center(
        child: Text(
          'No communities found',
          style: TextStyle(color: AppColors.onSurfaceVariant),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _communityResults.length,
      itemBuilder: (context, index) {
        final community = _communityResults[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: CommunityPreviewWidget(
            id: community['id'] ?? 0,
            name: community['name'] ?? '',
            description: community['description'] ?? '',
            participantCount: community['participant_count'] ?? 0,
            postCount: community['post_count'] ?? 0,
            joined: community['joined'] ?? false,
            onTap: () => context.push('/community/${community['id']}'),
            onJoin: community['joined'] == true
                ? null
                : () async {
                    try {
                      await Api.joinCommunity(community['id']);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Joined community!'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                        _search();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
          ),
        );
      },
    );
  }
}
