import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app/api.dart';
import 'package:app/widgets.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  List<dynamic> _conversations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    try {
      final conversations = await Api.getConversations(20, 0);
      if (mounted) {
        setState(() {
          _conversations = conversations;
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
      appBar: AppBar(title: const Text('Chats')),
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
            ElevatedButton(
              onPressed: _loadConversations,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_conversations.isEmpty) {
      return const Center(
        child: Text(
          'No conversations yet.\nConnect with someone to start chatting!',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.onSurfaceVariant),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          final conversation = _conversations[index];
          final otherUser = conversation['other_user'] as Map<String, dynamic>?;
          final lastMessage =
              conversation['last_message'] as Map<String, dynamic>?;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Text(
                  (otherUser?['username'] as String? ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                otherUser?['username'] ?? 'Unknown',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                lastMessage?['content'] ?? '',
                style: const TextStyle(color: AppColors.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
              onTap: () => context.push('/chat/${conversation['id']}'),
            ),
          );
        },
      ),
    );
  }
}
