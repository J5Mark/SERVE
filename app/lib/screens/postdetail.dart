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

  @override
  void initState() {
    super.initState();
    _loadPost();
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
    final webUrl = 'https://serve-back.ftp.sh/post/g/${widget.postId}';

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
          const SnackBar(
            content: Text('Contact added! Starting chat...'),
            backgroundColor: AppColors.brightGreen,
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
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _sharePost(),
            tooltip: 'Share Post',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: $_error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadPost,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _buildContent(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showContactsSheet,
        backgroundColor: AppColors.brightGreen,
        icon: const Icon(Icons.people),
        label: const Text('Get Contacts'),
      ),
    );
  }

  Widget _buildContent() {
    if (_post == null) {
      return const Center(
        child: Text('Post not found', style: TextStyle(color: AppColors.grey)),
      );
    }

    final post = _post!;
    final stats = _stats;

    return RefreshIndicator(
      onRefresh: _loadPost,
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    post['contents'] ?? '',
                    style: const TextStyle(
                      color: AppColors.lightGrey,
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
            const Text(
              'Competition Analysis',
              style: TextStyle(
                color: Colors.white,
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
                  backgroundColor: AppColors.brightGreen,
                  child: Text(
                    (contact['username'] as String? ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '@${contact['username'] ?? ''}',
                        style: const TextStyle(
                          color: AppColors.grey,
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
              style: const TextStyle(color: AppColors.lightGrey, fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.timer, size: 14, color: AppColors.brightGreen),
                const SizedBox(width: 4),
                Text(
                  'Responds in ${contact['reaction_time'] ?? '?'} days',
                  style: const TextStyle(
                    color: AppColors.lightGrey,
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
                  color: AppColors.yellowAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.handshake,
                      size: 14,
                      color: AppColors.yellowAccent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Goal: ${contact['cont_goal']}',
                        style: const TextStyle(
                          color: AppColors.lightGrey,
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
                  backgroundColor: AppColors.brightGreen,
                  foregroundColor: Colors.white,
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
