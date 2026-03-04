import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app/api.dart';
import 'package:app/widgets.dart';

class SearchPostScreen extends StatefulWidget {
  const SearchPostScreen({super.key});

  @override
  State<SearchPostScreen> createState() => _SearchPostScreenState();
}

class _SearchPostScreenState extends State<SearchPostScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _error;

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _error = null;
    });

    try {
      final results = await Api.searchPosts(query, 20);
      if (mounted) {
        setState(() {
          _results = results;
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Posts'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search for posts...',
                hintStyle: const TextStyle(color: AppColors.grey),
                prefixIcon: const Icon(Icons.search, color: AppColors.grey),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _results = [];
                      _hasSearched = false;
                    });
                  },
                ),
                filled: true,
                fillColor: AppColors.darkGreen,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Error: $_error',
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _search,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : !_hasSearched
                ? const Center(
                    child: Text(
                      'Enter a search query to find posts',
                      style: TextStyle(color: AppColors.grey),
                    ),
                  )
                : _results.isEmpty
                ? const Center(
                    child: Text(
                      'No posts found',
                      style: TextStyle(color: AppColors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final post = _results[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: PostWidget(
                          title: post['name'] ?? '',
                          content: post['contents'] ?? '',
                          average: (post['stats']?['mean'] ?? 0).toDouble(),
                          median: (post['stats']?['median'] ?? 0).toDouble(),
                          min: (post['stats']?['min'] ?? 0).toDouble(),
                          max: (post['stats']?['max'] ?? 0).toDouble(),
                          voteCount: post['stats']?['amount'] ?? 0,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
