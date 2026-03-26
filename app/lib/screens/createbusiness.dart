import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app/api.dart';
import 'package:app/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class CreateBusinessScreen extends StatefulWidget {
  const CreateBusinessScreen({super.key});

  @override
  State<CreateBusinessScreen> createState() => _CreateBusinessScreenState();
}

class _CreateBusinessScreenState extends State<CreateBusinessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _contGoalController = TextEditingController();
  List<dynamic> _communities = [];
  List<int> _selectedCommunityIds = [];
  int? _reactionTimeDays;
  bool _isLoading = false;
  bool _isLoadingCommunities = true;
  String? _error;
  XFile? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadCommunities();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _contGoalController.dispose();
    super.dispose();
  }

  Future<void> _loadCommunities() async {
    try {
      final hasToken = await Api.hasToken();
      if (hasToken) {
        final user = await Api.getUser();
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

  Future<void> _createBusiness() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCommunityIds.isEmpty) {
      setState(() => _error = 'Select at least one community');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await Api.createBusiness(
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        communityIds: _selectedCommunityIds,
        contGoal: _contGoalController.text.trim().isEmpty
            ? null
            : _contGoalController.text.trim(),
        reactionTimeDays: _reactionTimeDays,
      );

      if (_selectedImage != null) {
        final businessId = result['business_id'];
        if (businessId != null) {
          final bytes = await _selectedImage!.readAsBytes();
          await Api.uploadBusinessAvatar(businessId, bytes);
        }
      }

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
      appBar: AppBar(title: const Text('Create Business')),
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
                                style: TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                ),
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
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Business Name',
                          prefixIcon: Icon(Icons.business),
                        ),
                        maxLength: 20,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _bioController,
                        decoration: const InputDecoration(
                          labelText: 'What do you offer?',
                          prefixIcon: Icon(Icons.description),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 4,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Select Communities',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._communities.map(
                        (c) => CheckboxListTile(
                          title: Text(
                            c['name'] ?? '',
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            c['description'] ?? '',
                            style: TextStyle(color: AppColors.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          value: _selectedCommunityIds.contains(c['id']),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedCommunityIds.add(c['id']);
                              } else {
                                _selectedCommunityIds.remove(c['id']);
                              }
                            });
                          },
                          activeColor: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Contact Preferences (Optional)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _contGoalController,
                        decoration: const InputDecoration(
                          labelText: 'Contact Goal',
                          prefixIcon: Icon(Icons.handshake),
                          hintText: 'What kind of connections do you want?',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: _reactionTimeDays,
                        decoration: const InputDecoration(
                          labelText: 'Response Time',
                          prefixIcon: Icon(Icons.timer),
                        ),
                        dropdownColor: AppColors.surfaceContainer,
                        hint: const Text(
                          'How quickly can you respond?',
                          style: TextStyle(color: AppColors.onSurfaceVariant),
                        ),
                        items: [
                          const DropdownMenuItem<int>(
                            value: null,
                            child: Text(
                              'Not specified',
                              style: TextStyle(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          ...List.generate(14, (i) => i + 1).map(
                            (d) => DropdownMenuItem(
                              value: d,
                              child: Text('$d days'),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _reactionTimeDays = v),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.image),
                            label: Text(
                              _selectedImage != null
                                  ? 'Image selected'
                                  : 'Add Image',
                            ),
                          ),
                          if (_selectedImage != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () =>
                                  setState(() => _selectedImage = null),
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
                        onPressed: _isLoading ? null : _createBusiness,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Create Business'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
