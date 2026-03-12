import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app/api.dart';
import 'package:app/widgets.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentsController = TextEditingController();
  List<dynamic> _communities = [];
  int? _selectedCommunityId;
  bool _isLoading = false;
  bool _isLoadingCommunities = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCommunities();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentsController.dispose();
    super.dispose();
  }

  Future<void> _loadCommunities() async {
    try {
      final deviceId = await Api.getDeviceId();
      if (deviceId != null) {
        final user = await Api.getUser(deviceId);
        final communities = user['communities'] as List? ?? [];
        if (mounted) {
          setState(() {
            _communities = communities;
            _isLoadingCommunities = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingCommunities = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCommunities = false;
        });
      }
    }
  }

  String _getErrorMessage(dynamic e) {
    return e is ApiException ? e.displayMessage : e.toString();
  }

  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCommunityId == null) {
      setState(() => _error = 'Please select a community');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Api.createPost(
        name: _titleController.text.trim(),
        contents: _contentsController.text.trim(),
        communityId: _selectedCommunityId!,
      );

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _getErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Post')),
      body: _isLoadingCommunities
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_communities.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(
                                'You need to join a community first',
                                style: TextStyle(color: AppColors.grey),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () =>
                                    context.push('/create-community'),
                                child: const Text('Create Community'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      DropdownButtonFormField<int>(
                        value: _selectedCommunityId,
                        decoration: const InputDecoration(
                          labelText: 'Community',
                          prefixIcon: Icon(Icons.group),
                        ),
                        items: _communities.map<DropdownMenuItem<int>>((c) {
                          return DropdownMenuItem(
                            value: c['id'] as int,
                            child: Text(c['name'] ?? ''),
                          );
                        }).toList(),
                        onChanged: (v) =>
                            setState(() => _selectedCommunityId = v),
                        validator: (v) =>
                            v == null ? 'Select a community' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _contentsController,
                        decoration: const InputDecoration(
                          labelText: 'What do you need?',
                          prefixIcon: Icon(Icons.description),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 5,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 24),
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                      ],
                      ElevatedButton(
                        onPressed: _isLoading ? null : _createPost,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brightGreen,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Post'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
