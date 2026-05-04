import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/medical_record.dart';
import '../../../../presentation/widgets/app_network_image.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';

class RecordCard extends StatefulWidget {
  final MedicalRecord record;
  final String? patientAvatarUrl;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onFileTap;

  const RecordCard({
    super.key,
    required this.record,
    this.patientAvatarUrl,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onFileTap,
  });

  @override
  State<RecordCard> createState() => _RecordCardState();
}

class _RecordCardState extends State<RecordCard> with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  double _dragExtent = 0.0;
  final double _maxSlide = 140.0;
  Timer? _unlockTimer;

  bool get _isRecordLocked {
    final lockedUntil = widget.record.lockedUntil;
    return lockedUntil != null && lockedUntil.isAfter(DateTime.now());
  }

  @override
  void initState() {
    super.initState();
    _setupUnlockTimer();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(-0.38, 0)).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void didUpdateWidget(RecordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.record.lockedUntil != oldWidget.record.lockedUntil) {
      _setupUnlockTimer();
    }
  }

  void _setupUnlockTimer() {
    _unlockTimer?.cancel();
    if (_isRecordLocked) {
      final remaining = widget.record.lockedUntil!.difference(DateTime.now());
      if (remaining.inMilliseconds > 0) {
        _unlockTimer = Timer(remaining, () {
          if (mounted) setState(() {});
        });
      }
    }
  }

  @override
  void dispose() {
    _unlockTimer?.cancel();
    _slideController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerLockedFeedback() {
    HapticFeedback.heavyImpact();
    _shakeController.forward(from: 0.0);
    CustomSnackbar.showInfo(context, 'This record is locked for review.');
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_isRecordLocked) {
      _dragExtent += details.primaryDelta! * 0.15;
      if (_dragExtent > 0) _dragExtent = 0;
      if (_dragExtent < -25) _dragExtent = -25;
      _slideController.value = _dragExtent.abs() / _maxSlide;
      return;
    }

    _dragExtent += details.primaryDelta!;
    if (_dragExtent > 0) _dragExtent = 0;
    if (_dragExtent < -_maxSlide) _dragExtent = -_maxSlide;
    _slideController.value = _dragExtent.abs() / _maxSlide;
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_isRecordLocked) {
      _slideController.reverse();
      if (_dragExtent < -10) {
        _triggerLockedFeedback();
      }
      _dragExtent = 0;
      return;
    }

    if (_slideController.value > 0.4 || details.primaryVelocity! < -500) {
      _slideController.forward();
      HapticFeedback.selectionClick();
    } else {
      _slideController.reverse();
    }
    _dragExtent = _slideController.value * -_maxSlide;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPrescription = widget.record.recordType == 'Prescription';

    return SizedBox(
      height: 104,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              padding: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      _slideController.reverse();
                      widget.onEdit();
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: AppColors.primaryGreen,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      _slideController.reverse();
                      widget.onDelete();
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.dangerRed.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.dangerRed,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SlideTransition(
            position: _slideAnimation,
            child: GestureDetector(
              onHorizontalDragUpdate: _handleDragUpdate,
              onHorizontalDragEnd: _handleDragEnd,
              onTap: () {
                if (_isRecordLocked) {
                  _triggerLockedFeedback();
                  return;
                }
                if (_slideController.isCompleted) {
                  _slideController.reverse();
                } else {
                  widget.onFileTap();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryGreen.withValues(alpha: 0.1),
                              border: Border.all(
                                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                                width: 1.5,
                              ),
                            ),
                            child: ClipOval(
                              child: widget.patientAvatarUrl != null &&
                                      widget.patientAvatarUrl!.isNotEmpty
                                  ? AppNetworkImage(
                                      imageUrl: widget.patientAvatarUrl!,
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                    )
                                  : const Icon(
                                      Icons.person_rounded,
                                      color: AppColors.primaryGreen,
                                      size: 28,
                                    ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: isPrescription ? Colors.orange : AppColors.primaryGreen,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.surface,
                                  width: 2.5,
                                ),
                              ),
                              child: Icon(
                                isPrescription
                                    ? Icons.medical_services_rounded
                                    : Icons.analytics_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.record.recordFor,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.record.recordType,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isPrescription ? Colors.orange : AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          DateFormat('MMM dd').format(widget.record.recordDate),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_isRecordLocked)
                          AnimatedBuilder(
                            animation: _shakeAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(_shakeAnimation.value, 0),
                                child: child,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.lock_rounded,
                                    size: 12,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Locked',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (widget.record.fileUrls.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.attachment_rounded,
                                  size: 12,
                                  color: Colors.grey[500],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.record.fileUrls.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
