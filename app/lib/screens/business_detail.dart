import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app/api.dart';
import 'package:app/widgets.dart';

class BusinessDetailScreen extends StatefulWidget {
  final int businessId;

  const BusinessDetailScreen({super.key, required this.businessId});

  @override
  State<BusinessDetailScreen> createState() => _BusinessDetailScreenState();
}

class _BusinessDetailScreenState extends State<BusinessDetailScreen> {
  Map<String, dynamic>? _business;
  bool _isLoading = true;
  String? _error;
  bool _isEditing = false;
  bool _isSaving = false;

  final _bioController = TextEditingController();
  final _contGoalController = TextEditingController();
  int? _reactionTimeDays;
  List<int> _selectedCommunityIds = [];

  @override
  void initState() {
    super.initState();
    _loadBusiness();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _contGoalController.dispose();
    super.dispose();
  }

  Future<void> _loadBusiness() async {
    try {
      final business = await Api.getBusiness(widget.businessId);
      if (mounted) {
        setState(() {
          _business = business;
          _bioController.text = business['bio'] ?? '';
          _contGoalController.text = business['cont_goal'] ?? '';
          _reactionTimeDays = business['reaction_time'];
          _selectedCommunityIds =
              (business['community_ids'] as List?)?.cast<int>() ?? [];
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

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      await Api.editBusiness(
        businessId: widget.businessId,
        bio: _bioController.text.trim(),
        contGoal: _contGoalController.text.trim().isEmpty
            ? null
            : _contGoalController.text.trim(),
        reactionTimeDays: _reactionTimeDays,
        communityIds: _selectedCommunityIds.isEmpty
            ? null
            : _selectedCommunityIds,
      );
      if (mounted) {
        setState(() => _isEditing = false);
        _loadBusiness();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Business updated'),
            backgroundColor: AppColors.brightGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showVerifySheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Verify Business',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.visibility,
                color: AppColors.brightGreen,
              ),
              title: const Text('Seen', style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                'I have seen this business work',
                style: TextStyle(color: AppColors.grey),
              ),
              onTap: () => _verify('seen'),
            ),
            ListTile(
              leading: const Icon(
                Icons.check_circle,
                color: AppColors.yellowAccent,
              ),
              title: const Text('Used', style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                'I have used their services',
                style: TextStyle(color: AppColors.grey),
              ),
              onTap: () => _verify('use'),
            ),
            ListTile(
              leading: const Icon(Icons.handshake, color: Colors.blue),
              title: const Text(
                'Cooperated',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'I am willing to cooperate',
                style: TextStyle(color: AppColors.grey),
              ),
              onTap: () => _verify('coop'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _verify(String type) async {
    Navigator.pop(context);
    try {
      await Api.verifyBusiness(widget.businessId, type);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Business verified'),
            backgroundColor: AppColors.brightGreen,
          ),
        );
        _loadBusiness();
      }
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
        title: Text(_business?['name'] ?? 'Business'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              onPressed: _isSaving ? null : _saveChanges,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error'));

    final business = _business!;
    final verifications =
        business['verifications'] as Map<String, dynamic>? ?? {};
    final seenCount = verifications['seen'] ?? 0;
    final usedCount = (verifications['use'] ?? 0) as int;

    return RefreshIndicator(
      onRefresh: _loadBusiness,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.yellowAccent,
                        child: Text(
                          (business['name'] as String? ?? 'B')[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primaryBlack,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          business['name'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isEditing) ...[
                    TextFormField(
                      controller: _bioController,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        labelStyle: TextStyle(color: AppColors.grey),
                      ),
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                    ),
                  ] else ...[
                    Text(
                      business['bio'] ?? '',
                      style: const TextStyle(
                        color: AppColors.lightGrey,
                        fontSize: 15,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TrustStatsRow(seenCount: seenCount, usedCount: usedCount),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contact Preferences',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isEditing) ...[
                    TextFormField(
                      controller: _contGoalController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Goal',
                        labelStyle: TextStyle(color: AppColors.grey),
                        hintText: 'What kind of connections do you want?',
                        hintStyle: TextStyle(color: AppColors.grey),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _reactionTimeDays,
                      decoration: const InputDecoration(
                        labelText: 'Response Time',
                        labelStyle: TextStyle(color: AppColors.grey),
                      ),
                      dropdownColor: AppColors.darkGreen,
                      style: const TextStyle(color: Colors.white),
                      items: List.generate(14, (i) => i + 1)
                          .map(
                            (d) => DropdownMenuItem(
                              value: d,
                              child: Text('$d days'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _reactionTimeDays = v),
                    ),
                  ] else ...[
                    if (business['cont_goal'] != null &&
                        (business['cont_goal'] as String).isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.handshake,
                            size: 16,
                            color: AppColors.yellowAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Goal: ${business['cont_goal']}',
                              style: const TextStyle(
                                color: AppColors.lightGrey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (business['reaction_time'] != null) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.timer,
                            size: 16,
                            color: AppColors.brightGreen,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Responds in ${business['reaction_time']} days',
                            style: const TextStyle(color: AppColors.lightGrey),
                          ),
                        ],
                      ),
                    ],
                    if ((business['cont_goal'] == null ||
                            (business['cont_goal'] as String).isEmpty) &&
                        business['reaction_time'] == null)
                      Text(
                        'No contact preferences set',
                        style: TextStyle(color: AppColors.grey),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Communities',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isEditing) ...[
                    Text(
                      'Select communities:',
                      style: TextStyle(color: AppColors.grey),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder(
                      future: Api.getUserBusinesses().then((_) async {
                        final deviceId = await Api.getDeviceId();
                        if (deviceId != null) {
                          final user = await Api.getUser(deviceId);
                          return user['communities'] as List? ?? [];
                        }
                        return [];
                      }),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData)
                          return const CircularProgressIndicator();
                        final communities = snapshot.data!;
                        return Column(
                          children: communities
                              .map<Widget>(
                                (c) => CheckboxListTile(
                                  title: Text(
                                    c['name'] ?? '',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  value: _selectedCommunityIds.contains(
                                    c['id'],
                                  ),
                                  onChanged: (v) {
                                    setState(() {
                                      if (v == true) {
                                        _selectedCommunityIds.add(c['id']);
                                      } else {
                                        _selectedCommunityIds.remove(c['id']);
                                      }
                                    });
                                  },
                                  activeColor: AppColors.brightGreen,
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  ] else ...[
                    if (_business!['community_ids'] != null &&
                        (_business!['community_ids'] as List).isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (_business!['community_ids'] as List)
                            .map(
                              (id) => Chip(
                                label: Text(
                                  'Community $id',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                backgroundColor: AppColors.darkGreen,
                              ),
                            )
                            .toList(),
                      )
                    else
                      Text(
                        'No communities',
                        style: TextStyle(color: AppColors.grey),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
