import 'package:flutter/material.dart';

import 'package:site_lapse/core/app_theme.dart';

class ProjectClientCard extends StatelessWidget {
  const ProjectClientCard({
    super.key,
    required this.client,
    required this.isDark,
  });

  final Map<String, dynamic> client;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final name = client['name']?.toString() ?? 'Client';
    final phone = client['phone']?.toString() ?? '';
    final email = client['email']?.toString() ?? '';
    final initials = name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    final foreground = isDark ? Colors.white : Colors.black;
    final muted = isDark ? Colors.white60 : Colors.black54;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: .35)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .04),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: AppColors.primary,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (phone.isNotEmpty)
                  _ContactLine(
                    icon: Icons.phone_outlined,
                    value: phone,
                    color: muted,
                  ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _ContactLine(
                    icon: Icons.mail_outline,
                    value: email,
                    color: muted,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          value,
          style: TextStyle(color: color, fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}
