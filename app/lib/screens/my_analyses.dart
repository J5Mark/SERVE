import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app/api.dart';
import 'package:app/widgets.dart';

class MyAnalysesScreen extends StatefulWidget {
  const MyAnalysesScreen({super.key});

  @override
  State<MyAnalysesScreen> createState() => _MyAnalysesScreenState();
}

class _MyAnalysesScreenState extends State<MyAnalysesScreen> {
  List<dynamic> _analyses = [];
  bool _isLoading = true;
  String? _error;
  int _offset = 0;
  bool _hasMore = true;
  int? _statusCode;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadAnalyses();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoading) {
        _loadAnalyses();
      }
    }
  }

  Future<void> _loadAnalyses() async {
    if (_isLoading && _offset > 0) return;

    setState(() {
      if (_offset == 0) {
        _isLoading = true;
      }
      _error = null;
      _statusCode = null;
    });

    try {
      final analyses = await Api.getMyAnalyses(20, _offset);
      if (mounted) {
        setState(() {
          _analyses.addAll(analyses);
          _hasMore = analyses.length == 20;
          _offset += analyses.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _parseError(e);
          _statusCode = _extractStatusCode(e);
          _isLoading = false;
        });
      }
    }
  }

  String _parseError(dynamic e) {
    if (e is ApiException) {
      return e.displayMessage;
    }
    if (e is Exception) {
      final msg = e.toString();
      if (msg.contains('SocketException') || msg.contains('Connection')) {
        return 'Network error: Please check your internet connection';
      }
      if (msg.contains('TimeoutException')) {
        return 'Request timed out: Please try again';
      }
      return msg
          .replaceAll('Exception: ', '')
          .replaceAll('FormatException: ', '');
    }
    return 'An unexpected error occurred';
  }

  int? _extractStatusCode(dynamic e) {
    if (e is ApiException) {
      return e.statusCode;
    }
    return null;
  }

  Future<void> _refresh() async {
    _analyses = [];
    _offset = 0;
    _hasMore = true;
    await _loadAnalyses();
  }

  IconData _getErrorIcon() {
    if (_statusCode != null) {
      if (_statusCode == 401) return Icons.lock;
      if (_statusCode == 403) return Icons.block;
      if (_statusCode == 404) return Icons.search_off;
      if (_statusCode == 500) return Icons.cloud_off;
      if (_statusCode != null && _statusCode! >= 500) return Icons.cloud_off;
    }
    if (_error?.contains('Network') == true ||
        _error?.contains('internet') == true) {
      return Icons.wifi_off;
    }
    if (_error?.contains('timeout') == true) {
      return Icons.timer_off;
    }
    return Icons.error_outline;
  }

  String _getErrorHint() {
    if (_statusCode == 401) {
      return 'Please log in again';
    }
    if (_statusCode == 403) {
      return 'You do not have permission to view analyses';
    }
    if (_statusCode == 404) {
      return 'The endpoint may not be available yet';
    }
    if (_statusCode != null && _statusCode! >= 500) {
      return 'Server error. Please try again later';
    }
    if (_error?.contains('Network') == true ||
        _error?.contains('internet') == true) {
      return 'Check your WiFi or mobile data';
    }
    if (_error?.contains('timeout') == true) {
      return 'The server is taking too long to respond';
    }
    return 'If this persists, please contact support';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Analyses'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _analyses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _analyses.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_getErrorIcon(), size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              const Text(
                'Failed to load analyses',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              if (_statusCode != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Error $_statusCode',
                    style: TextStyle(
                      color: Colors.red.shade300,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getErrorHint(),
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _loadAnalyses,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_analyses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics, size: 64, color: AppColors.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text(
              'No analyses yet',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Request an analysis from a post page',
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _analyses.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _analyses.length) {
            _loadAnalyses();
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final analysis = _analyses[index];
          return _AnalysisCard(
            analysis: analysis,
            onTap: () => context.push('/analysis/${analysis['post_id']}'),
          );
        },
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  final Map<String, dynamic> analysis;
  final VoidCallback onTap;

  const _AnalysisCard({required this.analysis, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final postName = analysis['post_name'] ?? 'Unknown Post';
    final createdAt = analysis['created_at'] ?? '';

    String dateStr = '';
    if (createdAt.isNotEmpty) {
      try {
        final date = DateTime.parse(createdAt);
        dateStr = '${date.month}/${date.day}/${date.year}';
      } catch (_) {
        dateStr = createdAt;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.article, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      postName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dateStr,
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (analysis['Y'] != null ||
                  analysis['Z'] != null ||
                  analysis['U'] != null) ...[
                const SizedBox(height: 12),
                const Divider(color: AppColors.onSurfaceVariant, height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (analysis['Y'] != null) ...[
                      _AnalysisTag(label: 'Y', color: Colors.red),
                      const SizedBox(width: 8),
                    ],
                    if (analysis['Z'] != null) ...[
                      _AnalysisTag(label: 'Z', color: Colors.orange),
                      const SizedBox(width: 8),
                    ],
                    if (analysis['U'] != null) ...[
                      _AnalysisTag(label: 'U', color: Colors.green),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalysisTag extends StatelessWidget {
  final String label;
  final Color color;

  const _AnalysisTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
