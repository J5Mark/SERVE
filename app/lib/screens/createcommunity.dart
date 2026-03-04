import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app/api.dart';
import 'package:app/widgets.dart';

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

  Future<void> _createCommunity() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Api.createCommunity(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        redditLink: _redditLinkController.text.trim().isEmpty
            ? null
            : _redditLinkController.text.trim(),
        slug: _generateSlug(_nameController.text.trim()),
      );

      if (mounted) {
        context.pop();
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
                  backgroundColor: AppColors.brightGreen,
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
