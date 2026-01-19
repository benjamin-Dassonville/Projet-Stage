import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status; // "OK" | "KO" | "ABS" | autre
  const StatusBadge({super.key, required this.status});

  Color get bg {
    switch (status) {
      case 'OK':
        return Colors.green.shade100;
      case 'KO':
        return Colors.red.shade100;
      case 'ABS':
        return Colors.grey.shade300;
      default:
        return Colors.blueGrey.shade100;
    }
  }

  Color get fg {
    switch (status) {
      case 'OK':
        return Colors.green.shade900;
      case 'KO':
        return Colors.red.shade900;
      case 'ABS':
        return Colors.grey.shade800;
      default:
        return Colors.blueGrey.shade900;
    }
  }

  IconData? get icon {
    switch (status) {
      case 'OK':
        return Icons.check_circle;
      case 'KO':
        return Icons.cancel;
      case 'ABS':
        return Icons.block;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}