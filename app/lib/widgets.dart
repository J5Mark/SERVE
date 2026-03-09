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
                          AppColors.darkGreen.withValues(alpha: 0.5),
                          AppColors.primaryBlack.withValues(alpha: 0.7),
                          AppColors.darkGreen.withValues(alpha: 0.4),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
              ),
            ),
          ),
        Positioned.fill(
          child: CustomPaint(
            painter: _DottedGridPainter(
              dotColor: (dotColor ?? AppColors.yellowAccent).withValues(
                alpha: 0.15,
              ),
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
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brightGreen,
        brightness: Brightness.dark,
        primary: AppColors.brightGreen,
        secondary: AppColors.yellowAccent,
        surface: AppColors.primaryBlack,
      ),
      scaffoldBackgroundColor: AppColors.primaryBlack,
      cardTheme: CardThemeData(
        color: AppColors.darkGreen,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightGrey.withValues(alpha: 0.2),
        labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brightGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkGreen,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.grey.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: const BorderSide(color: AppColors.yellowAccent),
        ),
        labelStyle: const TextStyle(color: AppColors.grey),
        hintStyle: const TextStyle(color: AppColors.grey),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryBlack,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkGreen,
        selectedItemColor: AppColors.yellowAccent,
        unselectedItemColor: AppColors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.brightGreen,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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
        return AppColors.yellowAccent;
      case 'sponsor':
        return AppColors.brightGreen;
      case 'supplier':
        return Colors.blue;
      case 'community member':
        return Colors.purple;
      default:
        return AppColors.grey;
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
          colors: [AppColors.yellowAccent, AppColors.brightGreen],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Multi-Role ($businessRoleCount)',
        style: const TextStyle(
          color: AppColors.primaryBlack,
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
        Icon(Icons.visibility, size: 16, color: AppColors.grey),
        const SizedBox(width: 4),
        Text(
          'Seen: $seenCount',
          style: TextStyle(color: AppColors.grey, fontSize: 12),
        ),
        const SizedBox(width: 16),
        Icon(Icons.check_circle, size: 16, color: AppColors.brightGreen),
        const SizedBox(width: 4),
        Text(
          'Used: $usedCount',
          style: TextStyle(color: AppColors.brightGreen, fontSize: 12),
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
        color: AppColors.lightYellow.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.yellowAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_money, size: 16, color: AppColors.yellowAccent),
              const SizedBox(width: 4),
              Text(
                'Willingness to Pay',
                style: TextStyle(
                  color: AppColors.yellowAccent,
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
              Icon(Icons.how_to_vote, size: 14, color: AppColors.grey),
              const SizedBox(width: 4),
              Text(
                '$voteCount votes',
                style: TextStyle(color: AppColors.grey, fontSize: 12),
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
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(label, style: TextStyle(color: AppColors.grey, fontSize: 11)),
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
        color: AppColors.lightGrey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              Icon(Icons.arrow_upward, size: 14, color: AppColors.yellowAccent),
              const SizedBox(width: 2),
              Text(
                '$voteCount',
                style: TextStyle(color: AppColors.yellowAccent, fontSize: 13),
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
                  backgroundColor: AppColors.brightGreen,
                  child: Text(
                    '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}',
                    style: const TextStyle(
                      color: Colors.white,
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
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          if (editable)
                            Icon(Icons.edit, size: 16, color: AppColors.grey),
                        ],
                      ),
                      Text(
                        '@$username',
                        style: TextStyle(color: AppColors.grey, fontSize: 14),
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
                Icon(Icons.calendar_today, size: 14, color: AppColors.grey),
                const SizedBox(width: 4),
                Text(
                  'Member since $memberSince',
                  style: TextStyle(color: AppColors.grey, fontSize: 13),
                ),
              ],
            ),
            if (posts.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Posts (${posts.length})',
                style: const TextStyle(
                  color: Colors.white,
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

  const ProfileWidgetLight({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.roles,
    required this.memberSince,
    this.editable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: AppColors.yellowAccent.withValues(alpha: 0.5),
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
                backgroundColor: AppColors.brightGreen,
                child: Text(
                  '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}',
                  style: const TextStyle(
                    color: Colors.white,
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
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        if (editable)
                          const Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.black54,
                          ),
                      ],
                    ),
                    Text(
                      '@$username',
                      style: const TextStyle(
                        color: Colors.black54,
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
                    color: AppColors.yellowAccent.withValues(alpha: 0.2),
                    border: Border.all(color: AppColors.yellowAccent),
                  ),
                  child: Text(
                    roles.first,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                'Member since $memberSince',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
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
                        color: Colors.white,
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
                        color: AppColors.brightGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.brightGreen),
                      ),
                      child: const Text(
                        'Joined',
                        style: TextStyle(
                          color: AppColors.brightGreen,
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
                style: const TextStyle(color: AppColors.grey, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.people, size: 16, color: AppColors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '$participantCount',
                    style: const TextStyle(color: AppColors.grey, fontSize: 12),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.article, size: 16, color: AppColors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '$postCount',
                    style: const TextStyle(color: AppColors.grey, fontSize: 12),
                  ),
                  const Spacer(),
                  if (!joined && onJoin != null)
                    ElevatedButton(
                      onPressed: onJoin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brightGreen,
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
                    color: AppColors.darkGreen,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    communityName!,
                    style: const TextStyle(
                      color: AppColors.yellowAccent,
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
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                content,
                style: TextStyle(color: AppColors.lightGrey, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.attach_money,
                    size: 16,
                    color: AppColors.yellowAccent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Median: ${formatCurrency(median)}',
                    style: TextStyle(
                      color: AppColors.yellowAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  if (voteCount > 0) ...[
                    Icon(Icons.how_to_vote, size: 14, color: AppColors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '$voteCount',
                      style: TextStyle(color: AppColors.grey, fontSize: 13),
                    ),
                  ],
                  if (onVote != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.how_to_vote,
                        color: AppColors.brightGreen,
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
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: TextStyle(color: AppColors.lightGrey, fontSize: 14),
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
                      color: AppColors.brightGreen,
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
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(color: AppColors.lightGrey, fontSize: 14),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (showSensitiveData && serviceCommunities.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.groups, size: 16, color: AppColors.yellowAccent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Service: ${serviceCommunities.join(", ")}',
                      style: TextStyle(
                        color: AppColors.lightGrey,
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
                  Icon(Icons.timer, size: 16, color: AppColors.brightGreen),
                  const SizedBox(width: 6),
                  Text(
                    'Responds within $responseTimeDays days',
                    style: TextStyle(color: AppColors.lightGrey, fontSize: 13),
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
                style: TextStyle(color: AppColors.grey, fontSize: 12),
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
                      color: Colors.white,
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
              style: TextStyle(color: AppColors.grey, fontSize: 14),
            ),
            if (businessName != null) ...[
              const SizedBox(height: 12),
              Text(
                'Business: $businessName',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              if (businessBio != null) ...[
                const SizedBox(height: 4),
                Text(
                  businessBio!,
                  style: TextStyle(color: AppColors.lightGrey, fontSize: 13),
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
                  color: AppColors.yellowAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.interests,
                      size: 16,
                      color: AppColors.yellowAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Interested in: $interestedIn',
                        style: TextStyle(
                          color: AppColors.lightGrey,
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
              const Divider(color: AppColors.grey),
              const SizedBox(height: 12),
              if (phoneNumber != null) ...[
                Row(
                  children: [
                    Icon(Icons.phone, size: 16, color: AppColors.brightGreen),
                    const SizedBox(width: 8),
                    Text(
                      phoneNumber!,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ],
              if (responseTimeDays != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.timer, size: 16, color: AppColors.brightGreen),
                    const SizedBox(width: 8),
                    Text(
                      'Responds in $responseTimeDays days',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
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
                  backgroundColor: AppColors.brightGreen,
                  foregroundColor: Colors.white,
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
                    color: AppColors.yellowAccent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      color: AppColors.primaryBlack,
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
                      color: Colors.white,
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
              style: TextStyle(color: AppColors.lightGrey, fontSize: 14),
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
                      backgroundColor: AppColors.brightGreen,
                      foregroundColor: Colors.white,
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
