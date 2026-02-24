import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A switch that commits UI state only after async work succeeds.
class PessimisticSwitch extends StatefulWidget {
  final bool value;
  final bool enabled;
  final Color? activeColor;
  final Future<bool> Function(bool nextValue) onAttemptChange;

  const PessimisticSwitch({
    super.key,
    required this.value,
    required this.onAttemptChange,
    this.enabled = true,
    this.activeColor,
  });

  @override
  State<PessimisticSwitch> createState() => _PessimisticSwitchState();
}

class _PessimisticSwitchState extends State<PessimisticSwitch> {
  late bool _displayValue = widget.value;
  bool _isBusy = false;

  @override
  void didUpdateWidget(covariant PessimisticSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isBusy && widget.value != _displayValue) {
      _displayValue = widget.value;
    }
  }

  Future<void> _onChanged(bool nextValue) async {
    if (_isBusy || !widget.enabled) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    bool shouldCommit = false;
    try {
      shouldCommit = await widget.onAttemptChange(nextValue);
    } finally {
      // state update handled after async attempt
    }

    if (!mounted) {
      return;
    }

    setState(() {
      if (shouldCommit) {
        _displayValue = nextValue;
      }
      _isBusy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isBusy) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CupertinoActivityIndicator(radius: 8),
      );
    }

    return Switch.adaptive(
      value: _displayValue,
      activeColor: widget.activeColor,
      onChanged: widget.enabled ? _onChanged : null,
    );
  }
}
