import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app/api.dart';
import 'package:app/widgets.dart';

class ChatScreen extends StatefulWidget {
  final int conversationId;

  const ChatScreen({super.key, required this.conversationId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<dynamic> _messages = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _messageController = TextEditingController();
  Map<String, dynamic>? _otherUser;

  @override
  void initState() {
    super.initState();
    _loadChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadChat() async {
    setState(() => _isLoading = true);
    try {
      final data = await Api.getChat(widget.conversationId);
      if (mounted) {
        setState(() {
          _messages = data['messages'] ?? [];
          _otherUser = data['other_user'];
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

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    try {
      await Api.sendMessage(widget.conversationId, content);
      _messageController.clear();
      _loadChat();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_otherUser?['username'] ?? 'Chat'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
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
            ElevatedButton(onPressed: _loadChat, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          'No messages yet.\nSay hi!',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChat,
      child: ListView.builder(
        reverse: true,
        padding: const EdgeInsets.all(16),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[_messages.length - 1 - index];
          final isMe = message['is_me'] ?? false;

          return Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.brightGreen : AppColors.darkGreen,
                borderRadius: BorderRadius.circular(16),
              ),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message['content'] ?? '',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message['created_at']),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkGreen,
        border: Border(
          top: BorderSide(color: AppColors.grey.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(color: AppColors.grey),
                filled: true,
                fillColor: AppColors.primaryBlack,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sendMessage,
            icon: const Icon(Icons.send),
            color: AppColors.brightGreen,
          ),
        ],
      ),
    );
  }
}
