import 'package:flutter/material.dart';
import '../core/colors.dart';

enum StatusType { running, waiting, success, failed, pending }

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.type});

  final String label;
  final StatusType type;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (type) {
      StatusType.running => (ShipItColors.info, Icons.sync),
      StatusType.waiting => (ShipItColors.warning, Icons.hourglass_empty),
      StatusType.success => (ShipItColors.success, Icons.check_circle),
      StatusType.failed => (ShipItColors.error, Icons.error),
      StatusType.pending => (ShipItColors.pending, Icons.schedule),
    };

    return Semantics(
      label: 'Status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 14, color: color)),
            const SizedBox(width: 4),
            Flexible(
              child: ExcludeSemantics(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
