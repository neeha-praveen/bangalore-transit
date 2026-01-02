import 'package:flutter/material.dart';

class TimelineStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isLast;
  final bool isTransfer;
  final Color color;
  final IconData icon;

  const TimelineStep({
    super.key,
    required this.title,
    required this.subtitle,
    this.isLast = false,
    this.isTransfer = false,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline column
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: isTransfer ? Colors.white : color,
                border: Border.all(color: color, width: 3),
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(width: 2, height: 50, color: color.withOpacity(0.6)),
          ],
        ),

        const SizedBox(width: 12),

        // Text content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: isTransfer ? 26 : 20),
                const SizedBox(width: 10),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isTransfer ? 17 : 16,
                        fontWeight: isTransfer
                            ? FontWeight.bold
                            : FontWeight.w600,
                      ),
                    ),

                    // 🔹 Subtitle (replaced as requested)
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
