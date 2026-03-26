import 'package:flutter/material.dart';

class DottedGridBackground extends StatelessWidget {
  final Widget child;
  final Color? dotColor;
  final double dotSpacing;
  final double dotRadius;
  final bool showGradient;
  final List<Color>? gradientColors;

  const DottedGridBackground({
    super.key,
    required this.child,
    this.dotColor,
    this.dotSpacing = 30,
    this.dotRadius = 2.0,
    this.showGradient = true,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (showGradient || gradientColors != null)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: gradientColors != null
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: gradientColors!,
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.surfaceContainer.withValues(alpha: 0.5),
                          AppColors.surface.withValues(alpha: 0.7),
                          AppColors.surfaceContainer.withValues(alpha: 0.4),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
              ),
            ),
          ),
        Positioned.fill(
          child: CustomPaint(
            painter: _DottedGridPainter(
              dotColor: (dotColor ?? AppColors.primary).withValues(alpha: 0.08),
              dotSpacing: dotSpacing,
              dotRadius: dotRadius,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _DottedGridPainter extends CustomPainter {
  final Color dotColor;
  final double dotSpacing;
  final double dotRadius;

  _DottedGridPainter({
    required this.dotColor,
    required this.dotSpacing,
    required this.dotRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += dotSpacing) {
      for (double y = 0; y < size.height; y += dotSpacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String formatCurrency(double amount, {String currency = '\$'}) {
  return '$currency${amount.toStringAsFixed(0)}';
}

class AppColors {
  static const Color primaryBlack = Color(0xFF000007);
  static const Color darkGreen = Color(0xFF121717);
  static const Color brightGreen = Color(0xFF3A3AFF);
  static const Color yellowAccent = Color(0xFF52E8FF);
  static const Color lightYellow = Color(0xFFF0F3BD);
  static const Color grey = Color(0xFF6C757D);
  static const Color lightGrey = Color(0xFFE9ECEF);

  static const Color inverseOnSurface = Color(0xFF235c68);
  static const Color secondary = Color(0xFF00dcfd);
  static const Color primary = Color(0xFF6feffb);
  static const Color primaryDim = Color(0xFF5fe1ed);
  static const Color surfaceContainer = Color(0xFF001d23);
  static const Color inverseSurface = Color(0xFFf0fbff);
  static const Color onSecondaryContainer = Color(0xFFebfaff);
  static const Color secondaryFixedDim = Color(0xFF00d6f6);
  static const Color surfaceDim = Color(0xFF001115);
  static const Color surfaceContainerHigh = Color(0xFF00242a);
  static const Color outline = Color(0xFF477d8a);
  static const Color onTertiaryFixedVariant = Color(0xFF003b68);
  static const Color tertiaryFixed = Color(0xFF74b4ff);
  static const Color inversePrimary = Color(0xFF006a71);
  static const Color errorDim = Color(0xFFd7383b);
  static const Color onTertiaryContainer = Color(0xFF002647);
  static const Color tertiaryDim = Color(0xFF4ca2f9);
  static const Color secondaryDim = Color(0xFF00cdec);
  static const Color onTertiary = Color(0xFF00325a);
  static const Color onErrorContainer = Color(0xFFffa8a3);
  static const Color onSecondary = Color(0xFF004955);
  static const Color tertiaryFixedDim = Color(0xFF52a7ff);
  static const Color onTertiaryFixed = Color(0xFF001931);
  static const Color onSurface = Color(0xFFb8eefd);
  static const Color primaryContainer = Color(0xFF1bb4c0);
  static const Color primaryFixedDim = Color(0xFF5fe1ed);
  static const Color onSecondaryFixedVariant = Color(0xFF005967);
  static const Color surfaceBright = Color(0xFF00313a);
  static const Color surfaceContainerLow = Color(0xFF00161b);
  static const Color surface = Color(0xFF001115);
  static const Color surfaceContainerHighest = Color(0xFF002a32);
  static const Color secondaryContainer = Color(0xFF006878);
  static const Color error = Color(0xFFff716c);
  static const Color outlineVariant = Color(0xFF114f5b);
  static const Color secondaryFixed = Color(0xFF59e3ff);
  static const Color surfaceVariant = Color(0xFF002a32);
  static const Color onPrimaryFixed = Color(0xFF004348);
  static const Color surfaceTint = Color(0xFF6feffb);
  static const Color onSecondaryFixed = Color(0xFF003a44);
  static const Color background = Color(0xFF001115);
  static const Color errorContainer = Color(0xFF9f0519);
  static const Color onSurfaceVariant = Color(0xFF7eb3c1);
  static const Color onError = Color(0xFF490006);
  static const Color primaryFixed = Color(0xFF6feffb);
  static const Color surfaceContainerLowest = Color(0xFF000000);
  static const Color tertiary = Color(0xFF74b4ff);
  static const Color tertiaryContainer = Color(0xFF52a7ff);
  static const Color onPrimary = Color(0xFF00575e);
  static const Color onPrimaryContainer = Color(0xFF002a2e);
  static const Color onBackground = Color(0xFFb8eefd);
  static const Color onPrimaryFixedVariant = Color(0xFF006269);
}

class AppTheme {
  static ThemeMode _themeMode = ThemeMode.dark;
  static bool _isDarker = false;
  static final _listeners = ChangeNotifier();

  static ThemeMode get themeMode => _themeMode;
  static bool get isDarker => _isDarker;
  static ChangeNotifier get listener => _listeners;

  static void setDarkerMode(bool isDarker) {
    _isDarker = isDarker;
    _themeMode = ThemeMode.dark;
    _listeners.notifyListeners();
  }

  static ThemeData get theme {
    return _buildTheme(_isDarker);
  }

  static ThemeData _buildTheme(bool isDarker) {
    final surface = isDarker ? AppColors.primaryBlack : AppColors.surface;
    final surfaceContainer = isDarker
        ? const Color(0xFF0A0A10)
        : AppColors.surfaceContainer;
    final surfaceContainerHigh = isDarker
        ? const Color(0xFF121218)
        : AppColors.surfaceContainerHigh;
    final surfaceContainerHighest = isDarker
        ? const Color(0xFF1A1A24)
        : AppColors.surfaceContainerHighest;
    final onSurface = isDarker ? const Color(0xFFE0F7FA) : AppColors.onSurface;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: surface,
        onSurface: onSurface,
        surfaceContainerHighest: surfaceContainerHighest,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: surface,
      cardTheme: CardThemeData(
        color: surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceContainerHighest.withValues(alpha: 0.5),
        labelStyle: TextStyle(color: onSurface, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.primaryBlack,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: TextStyle(color: AppColors.onSurfaceVariant),
        hintStyle: TextStyle(color: AppColors.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface.withValues(alpha: 0.8),
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceContainer,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.primaryBlack,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class RoleChip extends StatelessWidget {
  final String role;

  const RoleChip({super.key, required this.role});

  static bool shouldDisplayRole(String role) {
    return role.toLowerCase() != 'community member';
  }

  Color _getRoleColor() {
    switch (role.toLowerCase()) {
      case 'entrepreneur':
        return AppColors.secondary;
      case 'sponsor':
        return AppColors.primary;
      case 'supplier':
        return AppColors.tertiary;
      case 'community member':
        return AppColors.primaryDim;
      default:
        return AppColors.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!shouldDisplayRole(role)) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getRoleColor().withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getRoleColor(), width: 1),
      ),
      child: Text(
        role,
        style: TextStyle(
          color: _getRoleColor(),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class MultiRoleBadge extends StatelessWidget {
  final List<String> roles;

  const MultiRoleBadge({super.key, required this.roles});

  int get businessRoleCount =>
      roles.where((r) => RoleChip.shouldDisplayRole(r)).length;

  @override
  Widget build(BuildContext context) {
    if (businessRoleCount < 2) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.secondary, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Multi-Role ($businessRoleCount)',
        style: const TextStyle(
          color: AppColors.onPrimary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class TrustStatsRow extends StatelessWidget {
  final int seenCount;
  final int usedCount;

  const TrustStatsRow({
    super.key,
    required this.seenCount,
    required this.usedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.visibility, size: 16, color: AppColors.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          'Seen: $seenCount',
          style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
        ),
        const SizedBox(width: 16),
        Icon(Icons.check_circle, size: 16, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(
          'Used: $usedCount',
          style: TextStyle(color: AppColors.primary, fontSize: 12),
        ),
      ],
    );
  }
}

class PaymentStatsRow extends StatelessWidget {
  final double average;
  final double median;
  final double min;
  final double max;
  final int voteCount;

  const PaymentStatsRow({
    super.key,
    required this.average,
    required this.median,
    required this.min,
    required this.max,
    required this.voteCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_money, size: 16, color: AppColors.secondary),
              const SizedBox(width: 4),
              Text(
                'Willingness to Pay',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatItem(label: 'Avg', value: '\$${average.toStringAsFixed(0)}'),
              _StatItem(
                label: 'Median',
                value: '\$${median.toStringAsFixed(0)}',
              ),
              _StatItem(label: 'Min', value: '\$${min.toStringAsFixed(0)}'),
              _StatItem(label: 'Max', value: '\$${max.toStringAsFixed(0)}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.how_to_vote,
                size: 14,
                color: AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '$voteCount votes',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11),
        ),
      ],
    );
  }
}

class PostMini extends StatelessWidget {
  final String title;
  final int voteCount;

  const PostMini({super.key, required this.title, required this.voteCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              Icon(Icons.arrow_upward, size: 14, color: AppColors.secondary),
              const SizedBox(width: 2),
              Text(
                '$voteCount',
                style: TextStyle(color: AppColors.secondary, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProfileWidget extends StatelessWidget {
  final String firstName;
  final String lastName;
  final String username;
  final List<String> roles;
  final String memberSince;
  final List<Map<String, dynamic>> posts;
  final bool editable;

  const ProfileWidget({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.roles,
    required this.memberSince,
    required this.posts,
    this.editable = false,
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
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}',
                    style: const TextStyle(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${firstName.isNotEmpty ? firstName : ''} ${lastName.isNotEmpty ? lastName : ''}'
                                  .trim(),
                              style: const TextStyle(
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          if (editable)
                            Icon(
                              Icons.edit,
                              size: 16,
                              color: AppColors.onSurfaceVariant,
                            ),
                        ],
                      ),
                      Text(
                        '@$username',
                        style: TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                MultiRoleBadge(roles: roles),
                if (roles
                        .where((r) => RoleChip.shouldDisplayRole(r))
                        .isNotEmpty &&
                    roles.where((r) => RoleChip.shouldDisplayRole(r)).length >=
                        2)
                  const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: roles
                        .where((role) => RoleChip.shouldDisplayRole(role))
                        .map((role) => RoleChip(role: role))
                        .toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'Member since $memberSince',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            if (posts.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Posts (${posts.length})',
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ...posts.map(
                (post) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: PostMini(
                    title: post['title'] ?? '',
                    voteCount: post['votes'] ?? 0,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ProfileWidgetLight extends StatelessWidget {
  final String firstName;
  final String lastName;
  final String username;
  final List<String> roles;
  final String memberSince;
  final bool editable;
  final String? avatarUrl;

  const ProfileWidgetLight({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.roles,
    required this.memberSince,
    this.editable = false,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary,
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl!)
                    : null,
                child: avatarUrl == null
                    ? Text(
                        '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}',
                        style: const TextStyle(
                          color: AppColors.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${firstName.isNotEmpty ? firstName : ''} ${lastName.isNotEmpty ? lastName : ''}'
                                .trim(),
                            style: const TextStyle(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        if (editable)
                          Icon(
                            Icons.edit,
                            size: 16,
                            color: AppColors.onSurfaceVariant,
                          ),
                      ],
                    ),
                    Text(
                      '@$username',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (roles.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.2),
                    border: Border.all(color: AppColors.secondary),
                  ),
                  child: Text(
                    roles.first,
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                'Member since $memberSince',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CommunityPreviewWidget extends StatelessWidget {
  final int id;
  final String name;
  final String description;
  final int participantCount;
  final int postCount;
  final bool joined;
  final VoidCallback? onTap;
  final VoidCallback? onJoin;

  const CommunityPreviewWidget({
    super.key,
    required this.id,
    required this.name,
    required this.description,
    required this.participantCount,
    required this.postCount,
    this.joined = false,
    this.onTap,
    this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (joined)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: const Text(
                        'Joined',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.people,
                    size: 16,
                    color: AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$participantCount',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.article,
                    size: 16,
                    color: AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$postCount',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  if (!joined && onJoin != null)
                    ElevatedButton(
                      onPressed: onJoin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: const Text('Join'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PostWidget extends StatelessWidget {
  final String title;
  final String content;
  final double median;
  final int voteCount;
  final VoidCallback? onVote;
  final VoidCallback? onTap;
  final bool compact;
  final String? communityName;
  final double? average;
  final double? min;
  final double? max;

  const PostWidget({
    super.key,
    required this.title,
    required this.content,
    this.median = 0,
    this.voteCount = 0,
    this.onVote,
    this.onTap,
    this.compact = false,
    this.communityName,
    this.average,
    this.min,
    this.max,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      Widget card = Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (communityName != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    communityName!,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                content,
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.attach_money,
                    size: 16,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Median: ${formatCurrency(median)}',
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  if (voteCount > 0) ...[
                    Icon(
                      Icons.how_to_vote,
                      size: 14,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$voteCount',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (onVote != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.how_to_vote,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      onPressed: onVote,
                      tooltip: 'Vote',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
      if (onTap != null) {
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: card,
        );
      }
      return card;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: PaymentStatsRow(
                    average: average ?? 0,
                    median: median,
                    min: min ?? 0,
                    max: max ?? 0,
                    voteCount: voteCount,
                  ),
                ),
                if (onVote != null)
                  IconButton(
                    icon: const Icon(
                      Icons.how_to_vote,
                      color: AppColors.primary,
                    ),
                    onPressed: onVote,
                    tooltip: 'Vote',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BusinessWidget extends StatelessWidget {
  final String name;
  final String description;
  final List<String> serviceCommunities;
  final int? responseTimeDays;
  final int seenCount;
  final int usedCount;
  final List<String>? contactWantsFrom;
  final String? contactGoal;
  final bool showSensitiveData;

  const BusinessWidget({
    super.key,
    required this.name,
    required this.description,
    required this.serviceCommunities,
    this.responseTimeDays,
    required this.seenCount,
    required this.usedCount,
    this.contactWantsFrom,
    this.contactGoal,
    this.showSensitiveData = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (showSensitiveData && serviceCommunities.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.groups, size: 16, color: AppColors.secondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Service: ${serviceCommunities.join(", ")}',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (showSensitiveData && responseTimeDays != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.timer, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Responds within $responseTimeDays days',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TrustStatsRow(seenCount: seenCount, usedCount: usedCount),
            if (showSensitiveData &&
                contactWantsFrom != null &&
                contactWantsFrom!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Wants contact from:',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: contactWantsFrom!
                    .map((role) => RoleChip(role: role))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ContactWidget extends StatelessWidget {
  final String name;
  final String username;
  final String? phoneNumber;
  final String role;
  final String? businessName;
  final String? businessBio;
  final int? responseTimeDays;
  final String? interestedIn;

  const ContactWidget({
    super.key,
    required this.name,
    required this.username,
    this.phoneNumber,
    required this.role,
    this.businessName,
    this.businessBio,
    this.responseTimeDays,
    this.interestedIn,
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
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                RoleChip(role: role),
              ],
            ),
            Text(
              '@$username',
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
            ),
            if (businessName != null) ...[
              const SizedBox(height: 12),
              Text(
                'Business: $businessName',
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 14,
                ),
              ),
              if (businessBio != null) ...[
                const SizedBox(height: 4),
                Text(
                  businessBio!,
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
            if (interestedIn != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.interests, size: 16, color: AppColors.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Interested in: $interestedIn',
                        style: TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (phoneNumber != null || responseTimeDays != null) ...[
              const SizedBox(height: 12),
              Divider(color: AppColors.outlineVariant),
              const SizedBox(height: 12),
              if (phoneNumber != null) ...[
                Row(
                  children: [
                    Icon(Icons.phone, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      phoneNumber!,
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
              if (responseTimeDays != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.timer, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Responds in $responseTimeDays days',
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Request Contact'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NewcomerWidget extends StatelessWidget {
  final String name;
  final String description;
  final int seenCount;
  final int usedCount;
  final VoidCallback? onVerify;

  const NewcomerWidget({
    super.key,
    required this.name,
    required this.description,
    required this.seenCount,
    required this.usedCount,
    this.onVerify,
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'NEW',
                    style: TextStyle(
                      color: AppColors.onSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            TrustStatsRow(seenCount: seenCount, usedCount: usedCount),
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onVerify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Verify'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AppRadius {
  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double xl = 20.0;
  static const BorderRadius smallRadius = BorderRadius.all(
    Radius.circular(small),
  );
  static const BorderRadius mediumRadius = BorderRadius.all(
    Radius.circular(medium),
  );
  static const BorderRadius largeRadius = BorderRadius.all(
    Radius.circular(large),
  );
  static const BorderRadius xlRadius = BorderRadius.all(Radius.circular(xl));
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final double borderRadius;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.backgroundColor,
    this.borderRadius = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.1),
        ),
      ),
      child: child,
    );
  }
}

class PrimaryChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool selected;
  final Color? color;

  const PrimaryChip({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.selected = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? chipColor.withValues(alpha: 0.2)
              : AppColors.surfaceContainerHighest,
          borderRadius: AppRadius.smallRadius,
          border: selected
              ? Border.all(color: chipColor.withValues(alpha: 0.5))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? chipColor : AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? chipColor : AppColors.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isOutlined;
  final double? width;

  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isOutlined = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: isOutlined
          ? OutlinedButton(
              onPressed: isLoading ? null : onPressed,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.smallRadius,
                ),
              ),
              child: _buildChild(AppColors.primary),
            )
          : Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryContainer],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: AppRadius.smallRadius,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isLoading ? null : onPressed,
                  borderRadius: AppRadius.smallRadius,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    child: _buildChild(AppColors.onPrimary),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildChild(Color color) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      );
    }

    return Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14),
    );
  }
}
