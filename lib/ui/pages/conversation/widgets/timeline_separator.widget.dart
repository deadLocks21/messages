import 'package:flutter/material.dart';
import 'package:messages/ui/theme/app_colors.dart';
import 'package:messages/ui/utils/date_format.dart';

/// Repère temporel centré entre deux salves de messages.
class TimelineSeparatorLabel extends StatelessWidget {
  const TimelineSeparatorLabel({super.key, required this.at, this.now});

  final DateTime at;

  /// Injectable pour les tests, comme pour la liste des conversations.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Text(
          MessagesDateFormat.separator(at, now: now),
          style: TextStyle(
            fontSize: 12,
            color: colors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
