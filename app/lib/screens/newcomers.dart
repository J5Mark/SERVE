import 'package:flutter/material.dart';
import 'package:app/api.dart';
import 'package:app/widgets.dart';

class NewcomersScreen extends StatefulWidget {
  const NewcomersScreen({super.key});

  @override
  State<NewcomersScreen> createState() => _NewcomersScreenState();
}

class _NewcomersScreenState extends State<NewcomersScreen> {
  List<dynamic> _businesses = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNewcomers();
  }

  Future<void> _loadNewcomers() async {
    try {
      final businesses = await Api.getNewcomerBusinesses(20);
      if (mounted) {
        setState(() {
          _businesses = businesses;
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

  Future<void> _verifyBusiness(int businessId) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: const Text(
          'Verify Business',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'How do you know this business?',
          style: TextStyle(color: AppColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'use'),
            child: const Text('Used their services'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'coop'),
            child: const Text('Want to cooperate'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'seen'),
            child: const Text('Seen them work'),
          ),
        ],
      ),
    );

    if (choice == null) return;

    try {
      await Api.verifyBusiness(businessId, choice);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Business verified!')));
        _loadNewcomers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Businesses')),
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
              onPressed: _loadNewcomers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_businesses.isEmpty) {
      return const Center(child: Text('No new businesses yet'));
    }

    return RefreshIndicator(
      onRefresh: _loadNewcomers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _businesses.length,
        itemBuilder: (context, index) {
          final business = _businesses[index];
          final verifications =
              business['verifications'] as Map<String, dynamic>? ?? {};
          final seenCount = verifications.length * 3;
          final usedCount = verifications.values.fold<int>(
            0,
            (a, b) => a + (b as int),
          );

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: NewcomerWidget(
              name: business['name'] ?? '',
              description: business['bio'] ?? '',
              seenCount: seenCount,
              usedCount: usedCount,
              onVerify: () => _verifyBusiness(business['id']),
            ),
          );
        },
      ),
    );
  }
}
