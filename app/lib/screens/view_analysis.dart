import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app/api.dart';
import 'package:app/widgets.dart';

class ViewAnalysisScreen extends StatefulWidget {
  final int postId;

  const ViewAnalysisScreen({super.key, required this.postId});

  @override
  State<ViewAnalysisScreen> createState() => _ViewAnalysisScreenState();
}

class _ViewAnalysisScreenState extends State<ViewAnalysisScreen> {
  Map<String, dynamic>? _analysis;
  bool _isLoading = true;
  String? _error;
  int? _statusCode;

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  Future<void> _loadAnalysis() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _statusCode = null;
    });

    try {
      final analysis = await Api.getAnalysis(widget.postId);
      if (mounted) {
        setState(() {
          _analysis = analysis;
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

  IconData _getErrorIcon() {
    if (_statusCode != null) {
      if (_statusCode == 401) return Icons.lock;
      if (_statusCode == 403) return Icons.block;
      if (_statusCode == 404) return Icons.search_off;
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
      return 'You do not have permission to view this analysis';
    }
    if (_statusCode == 404) {
      return 'Analysis not found or still processing';
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
        title: const Text('Analysis'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalysis,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_getErrorIcon(), size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              const Text(
                'Failed to load analysis',
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
                      style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
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
                    onPressed: _loadAnalysis,
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

    if (_analysis == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics, size: 64, color: AppColors.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text(
              'Analysis not found',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'The analysis may still be processing',
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAnalysis,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAnalysis,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_analysis!['Y'] != null) ...[
            _AnalysisSection(
              title: 'Y - Pain Point',
              content: _analysis!['Y'],
              color: Colors.red,
              icon: Icons.warning_amber,
            ),
            const SizedBox(height: 16),
          ],
          if (_analysis!['Z'] != null) ...[
            _AnalysisSection(
              title: 'Z - Competition',
              content: _analysis!['Z'],
              color: Colors.orange,
              icon: Icons.group_work,
            ),
            const SizedBox(height: 16),
          ],
          if (_analysis!['U'] != null) ...[
            _AnalysisSection(
              title: 'U - Unique Feature',
              content: _analysis!['U'],
              color: Colors.green,
              icon: Icons.star,
            ),
            const SizedBox(height: 16),
          ],
          if (_analysis!['additional'] != null) ...[
            _AnalysisSection(
              title: 'Additional Insights',
              content: _analysis!['additional'],
              color: AppColors.yellowAccent,
              icon: Icons.lightbulb,
            ),
            const SizedBox(height: 16),
          ],
          if (_analysis!['created_at'] != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(
                      'Generated: ${_formatDate(_analysis!['created_at'])}',
                      style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.article, color: AppColors.primary),
              title: const Text(
                'View Original Post',
                style: TextStyle(color: Colors.white),
              ),
              trailing: const Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
              onTap: () => context.push('/post/${widget.postId}'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}/${date.day}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}

class _AnalysisSection extends StatelessWidget {
  final String title;
  final String content;
  final Color color;
  final IconData icon;

  const _AnalysisSection({
    required this.title,
    required this.content,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.onSurfaceVariant, height: 1),
            const SizedBox(height: 12),
            SelectableText(
              content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
