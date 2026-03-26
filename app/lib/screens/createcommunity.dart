import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app/api.dart';
import 'package:app/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _redditLinkController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  XFile? _selectedImage;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _redditLinkController.dispose();
    super.dispose();
  }

  String _generateSlug(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');
  }

  Future<void> _pickImage() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Image upload is not available on web'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _selectedImage = image);
    }
  }

  Future<void> _createCommunity() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resp = await Api.createCommunity(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        redditLink: _redditLinkController.text.trim().isEmpty
            ? null
            : _redditLinkController.text.trim(),
        slug: _generateSlug(_nameController.text.trim()),
      );

      if (resp.containsKey('subreddit') &&
          resp['subreddit'] == 'doesnt exist') {
        setState(() {
          _error =
              'Reddit community does not exist. Please check the link and try again.';
          _isLoading = false;
        });
        return;
      }

      final communityId = resp['community_id'];
      if (_selectedImage != null && communityId != null) {
        final bytes = await _selectedImage!.readAsBytes();
        await Api.uploadCommunityAvatar(communityId, bytes);
      }

      if (mounted) {
        if (_redditLinkController.text.trim().isNotEmpty) {
          _showRedditTemplateDialog();
        } else {
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.displayMessage : e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showRedditTemplateDialog() {
    final redditLink = _redditLinkController.text.trim();

    final templatePost = '''Hey $redditLink! 👋

I've created a mirror community for us on Serve - a platform where we can connect, share opportunities, and grow together!

Check it out here: {community_link}

Why join?
- Connect with fellow entrepreneurs
- Share and discover business opportunities
- Build your network

Looking forward to seeing you there!

#Community #Entrepreneurs''';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: AppColors.onSurfaceVariant),
        ),
        title: const Text(
          'Community Created!',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your community has been created. Would you like to share it on Reddit?',
              style: TextStyle(color: AppColors.lightGrey),
            ),
            const SizedBox(height: 16),
            const Text(
              'Copy and paste this template to your Reddit community:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  left: BorderSide(color: AppColors.primary, width: 3),
                ),
              ),
              child: SelectableText(
                templatePost,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.lightGrey,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Reddit: ',
                  style: TextStyle(color: AppColors.onSurfaceVariant),
                ),
                Text(
                  redditLink,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.pop();
            },
            child: const Text(
              'Skip',
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Community')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Community Name',
                  prefixIcon: Icon(Icons.group),
                  hintText: 'e.g., Tech Startups',
                ),
                maxLength: 25,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 4) return 'Minimum 4 characters';
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description),
                  alignLabelWithHint: true,
                  hintText: 'What is this community about?',
                ),
                maxLines: 4,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 10) return 'Minimum 10 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _redditLinkController,
                decoration: const InputDecoration(
                  labelText: 'Reddit Link (optional)',
                  prefixIcon: Icon(Icons.link),
                  hintText: 'e.g., r/entrepreneur',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image),
                    label: Text(
                      _selectedImage != null ? 'Image selected' : 'Add Image',
                    ),
                  ),
                  if (_selectedImage != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _selectedImage = null),
                    ),
                  ],
                ],
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
                onPressed: _isLoading ? null : _createCommunity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Create Community'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
