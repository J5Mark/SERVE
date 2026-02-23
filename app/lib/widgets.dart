import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryBlack = Color(0xFF1A1A1A);
  static const Color darkGreen = Color(0xFF1B4332);
  static const Color brightGreen = Color(0xFF40916C);
  static const Color yellowAccent = Color(0xFFD4D700);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightGrey.withValues(alpha: 0.2),
        labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  const ProfileWidget({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.roles,
    required this.memberSince,
    required this.posts,
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
                    '${firstName[0]}${lastName[0]}',
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
                      Text(
                        '$firstName $lastName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
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

class PostWidget extends StatelessWidget {
  final String title;
  final String content;
  final double average;
  final double median;
  final double min;
  final double max;
  final int voteCount;

  const PostWidget({
    super.key,
    required this.title,
    required this.content,
    required this.average,
    required this.median,
    required this.min,
    required this.max,
    required this.voteCount,
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
            PaymentStatsRow(
              average: average,
              median: median,
              min: min,
              max: max,
              voteCount: voteCount,
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
  final VoidCallback? onDismiss;

  const NewcomerWidget({
    super.key,
    required this.name,
    required this.description,
    required this.seenCount,
    required this.usedCount,
    this.onVerify,
    this.onDismiss,
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
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDismiss,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.grey,
                      side: const BorderSide(color: AppColors.grey),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Dismiss'),
                  ),
                ),
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
