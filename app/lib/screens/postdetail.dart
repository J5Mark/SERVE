import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app/api.dart';
import 'package:app/widgets.dart';
import 'package:share_plus/share_plus.dart';

class PostDetailScreen extends StatefulWidget {
  final int postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Map<String, dynamic>? _post;
  Map<String, dynamic>? _stats;
  List<dynamic> _votes = [];
  bool _isLoading = true;
  String? _error;
  List<dynamic> _contacts = [];
  bool _isLoadingContacts = false;
  bool _isAnalyzing = false;
  String _analysisStatus = 'not_requested';

  @override
  void initState() {
    super.initState();
    _loadPost();
    _checkAnalysisStatus();
  }

  Future<void> _loadPost() async {
    try {
      final postData = await Api.getPost(widget.postId);

      if (mounted) {
        setState(() {
          _post = postData['post'];
          _stats = postData['stats'];
          _votes = postData['votes'] ?? [];
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

  Future<void> _sharePost() async {
    final postName = _post?['name'] ?? 'Check out this post';
    final webUrl = 'https://serveyourcommunity.ftp.sh/#/post/${widget.postId}';

    await Share.share('$postName\n\n$webUrl', subject: postName);
  }

  Future<void> _loadContacts() async {
    if (_post == null) return;

    setState(() {
      _isLoadingContacts = true;
    });

    try {
      final communityId = _post!['community_id'] as int;
      final contacts = await Api.getContacts(10, communityId, widget.postId);

      if (mounted) {
        setState(() {
          _contacts = contacts;
          _isLoadingContacts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingContacts = false;
        });
      }
    }
  }

  Future<void> _checkAnalysisStatus() async {
    try {
      final status = await Api.getAnalysisStatus(widget.postId);
      if (mounted) {
        setState(() {
          _analysisStatus = status['status'] ?? 'not_requested';
        });
      }
    } catch (e) {
      // Silently fail - analysis might not be requested yet
    }
  }

  Future<void> _requestAnalysis(bool fullAnalysis) async {
    setState(() {
      _isAnalyzing = true;
    });

    try {
      await Api.requestAnalysis(widget.postId, fullAnalysis: fullAnalysis);
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _analysisStatus = 'pending';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              fullAnalysis
                  ? 'Full analysis requested'
                  : 'Quick analysis requested',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to request analysis: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showAnalysisTypeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Request Analysis',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.bolt, color: AppColors.secondary),
              title: Text(
                'Quick Analysis',
                style: TextStyle(color: AppColors.onSurface),
              ),
              subtitle: Text(
                'Clustered votes only (faster)',
                style: TextStyle(color: AppColors.onSurfaceVariant),
              ),
              onTap: () {
                Navigator.pop(context);
                _requestAnalysis(false);
              },
            ),
            Divider(color: AppColors.outlineVariant),
            ListTile(
              leading: Icon(Icons.analytics, color: AppColors.primary),
              title: Text(
                'Full Analysis',
                style: TextStyle(color: AppColors.onSurface),
              ),
              subtitle: Text(
                'Y/Z/U extraction with AI (slower)',
                style: TextStyle(color: AppColors.onSurfaceVariant),
              ),
              onTap: () {
                Navigator.pop(context);
                _requestAnalysis(true);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showContactsSheet() {
    _loadContacts();
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
                    'Suggested Contacts',
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
            const Divider(color: AppColors.grey, height: 1),
            Expanded(
              child: _isLoadingContacts
                  ? const Center(child: CircularProgressIndicator())
                  : _contacts.isEmpty
                  ? const Center(
                      child: Text(
                        'No contacts available',
                        style: TextStyle(color: AppColors.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _contacts.length,
                      itemBuilder: (context, index) {
                        final contact = _contacts[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _ContactCard(
                            contact: contact,
                            onConnect: () =>
                                _connectContact(contact['user_id']),
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

  Future<void> _connectContact(int userId) async {
    try {
      await Api.addContacts([userId]);

      final conversation = await Api.createConversation(userId);
      final conversationId =
          conversation['conversation_id'] ?? conversation['id'];

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Contact added! Starting chat...'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context);
        if (conversationId != null) {
          context.push('/chat/$conversationId');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add contact: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('Post', style: TextStyle(color: AppColors.onSurface)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: AppColors.onSurfaceVariant),
            onPressed: () => _sharePost(),
            tooltip: 'Share Post',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: $_error',
                    style: TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _buildContent(),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_analysisStatus == 'pending')
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FloatingActionButton.small(
                heroTag: 'analysis_status',
                onPressed: null,
                backgroundColor: AppColors.secondary,
                child: Icon(
                  Icons.hourglass_empty,
                  color: AppColors.onSecondary,
                ),
              ),
            ),
          if (_isAnalyzing)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FloatingActionButton.small(
                heroTag: 'analyzing',
                onPressed: null,
                backgroundColor: AppColors.secondary,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onSecondary,
                  ),
                ),
              ),
            ),
          FloatingActionButton.extended(
            heroTag: 'contacts',
            onPressed: _showContactsSheet,
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            icon: const Icon(Icons.people),
            label: const Text('Get Contacts'),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'analyze',
            onPressed: _isAnalyzing ? null : _showAnalysisTypeSheet,
            backgroundColor: AppColors.secondary,
            child: Icon(Icons.analytics, color: AppColors.onSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_post == null) {
      return Center(
        child: Text(
          'Post not found',
          style: TextStyle(color: AppColors.onSurfaceVariant),
        ),
      );
    }

    final post = _post!;
    final stats = _stats;

    return RefreshIndicator(
      onRefresh: _loadPost,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    post['name'] ?? '',
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    post['contents'] ?? '',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 15,
                    ),
                  ),
                  if (stats != null) ...[
                    const SizedBox(height: 20),
                    PaymentStatsRow(
                      average: (stats['mean'] is num ? stats['mean'] : 0)
                          .toDouble(),
                      median: (stats['median'] is num ? stats['median'] : 0)
                          .toDouble(),
                      min: (stats['min'] is num ? stats['min'] : 0).toDouble(),
                      max: (stats['max'] is num ? stats['max'] : 0).toDouble(),
                      voteCount: stats['amount'] is int ? stats['amount'] : 0,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_votes.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Competition Analysis',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._votes.map(
              (vote) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _VoteCard(vote: vote),
              ),
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _VoteCard extends StatelessWidget {
  final Map<String, dynamic> vote;

  const _VoteCard({required this.vote});

  @override
  Widget build(BuildContext context) {
    final competition = vote['competition'] as String?;
    final problems = vote['problems'] as String?;

    if (competition == null && problems == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (competition != null && competition.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.group_work,
                    size: 16,
                    color: AppColors.yellowAccent,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Competition',
                    style: TextStyle(
                      color: AppColors.yellowAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                competition,
                style: const TextStyle(
                  color: AppColors.lightGrey,
                  fontSize: 14,
                ),
              ),
            ],
            if (competition != null &&
                competition.isNotEmpty &&
                problems != null &&
                problems.isNotEmpty)
              const SizedBox(height: 12),
            if (problems != null && problems.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text(
                    'Problems',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                problems,
                style: const TextStyle(
                  color: AppColors.lightGrey,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final Map<String, dynamic> contact;
  final VoidCallback onConnect;

  const _ContactCard({required this.contact, required this.onConnect});

  @override
  Widget build(BuildContext context) {
    final verificationStats =
        contact['verification_stats'] as Map<String, dynamic>?;
    final seenCount = verificationStats?['seen_count'] ?? 0;
    final usedCount = verificationStats?['used_count'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Text(
                    (contact['username'] as String? ?? 'U')[0].toUpperCase(),
                    style: TextStyle(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact['business_name'] ?? '',
                        style: TextStyle(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '@${contact['username'] ?? ''}',
                        style: TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              contact['business_bio'] ?? '',
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.timer, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  'Responds in ${contact['reaction_time'] ?? '?'} days',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TrustStatsRow(seenCount: seenCount, usedCount: usedCount),
            if (contact['cont_goal'] != null &&
                (contact['cont_goal'] as String).isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.handshake, size: 14, color: AppColors.secondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Goal: ${contact['cont_goal']}',
                        style: TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onConnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
                child: const Text('Connect'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
