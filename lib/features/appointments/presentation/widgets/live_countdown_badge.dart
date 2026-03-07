import 'dart:async';
import 'package:flutter/material.dart';

class LiveCountdownBadge extends StatefulWidget {
  final String status;
  final String scheduleDate; // e.g., "2023-10-25"
  final String startTime; // e.g., "13:00:00"
  final int maxWaitTime; // e.g., 30 (minutes)

  const LiveCountdownBadge({
    super.key,
    required this.status,
    required this.scheduleDate,
    required this.startTime,
    this.maxWaitTime = 30, // Default fallback
  });

  @override
  State<LiveCountdownBadge> createState() => _LiveCountdownBadgeState();
}

class _LiveCountdownBadgeState extends State<LiveCountdownBadge> {
  Timer? _timer;
  String _displayText = "";
  Color _badgeColor = Colors.grey;
  bool _isFlashing = false;

  @override
  void initState() {
    super.initState();
    _calculateTime();
    if (widget.status == 'waiting') {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _calculateTime();
      });
    }
  }

  @override
  void didUpdateWidget(covariant LiveCountdownBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      if (widget.status != 'waiting') {
        _timer?.cancel();
      } else if (_timer == null || !_timer!.isActive) {
        _timer = Timer.periodic(
          const Duration(seconds: 1),
          (timer) => _calculateTime(),
        );
      }
      _calculateTime();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculateTime() {
    if (widget.status == 'confirmed') {
      _setBadge("Confirmed", const Color(0xFF00C689), false);
      return;
    }
    if (widget.status != 'waiting') {
      _setBadge(widget.status.toUpperCase(), Colors.grey, false);
      return;
    }

    try {
      // 1. Calculate the exact timeline
      final startDateTime = DateTime.parse(
        "${widget.scheduleDate} ${widget.startTime}",
      );
      final gracePeriodStart = startDateTime.add(
        Duration(minutes: widget.maxWaitTime),
      );
      final deadline = gracePeriodStart.add(const Duration(minutes: 15));
      final now = DateTime.now();

      // 2. We are in the initial waiting period (Doctor is just busy)
      if (now.isBefore(gracePeriodStart)) {
        _setBadge("Waiting", Colors.amber, false);
        return;
      }

      // 3. We are in the final 15-minute countdown!
      if (now.isAfter(gracePeriodStart) && now.isBefore(deadline)) {
        final timeLeft = deadline.difference(now);
        final minutes = timeLeft.inMinutes.toString().padLeft(2, '0');
        final seconds = (timeLeft.inSeconds % 60).toString().padLeft(2, '0');

        // Turn red and flash when under 5 minutes
        final isCritical = timeLeft.inMinutes < 5;
        _setBadge(
          "Missed in $minutes:$seconds",
          isCritical ? Colors.red : Colors.deepOrange,
          isCritical,
        );
        return;
      }

      // 4. Time has completely expired (Waiting for DB to mark as missed)
      if (now.isAfter(deadline)) {
        _setBadge("Time Expired", Colors.red, false);
      }
    } catch (e) {
      _setBadge("Waiting", Colors.amber, false);
    }
  }

  void _setBadge(String text, Color color, bool flash) {
    if (mounted) {
      setState(() {
        _displayText = text;
        _badgeColor = color;
        _isFlashing = flash && (DateTime.now().second % 2 == 0); // Blink effect
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _badgeColor.withValues(alpha: _isFlashing ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _badgeColor.withValues(alpha: _isFlashing ? 0.8 : 0.3),
          width: _isFlashing ? 1.5 : 1.0,
        ),
      ),
      child: Text(
        _displayText,
        style: TextStyle(
          color: _badgeColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
