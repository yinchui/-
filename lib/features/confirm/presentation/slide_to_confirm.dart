import 'package:flutter/material.dart';
import 'package:medication_reminder/core/theme/app_theme.dart';

class SlideToConfirm extends StatefulWidget {
  const SlideToConfirm({
    required this.onConfirmed,
    this.enabled = true,
    super.key,
  });

  final Future<void> Function() onConfirmed;
  final bool enabled;

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm> {
  static const _thumbSize = 60.0;
  static const _confirmThreshold = 0.58;

  var _drag = 0.0;
  var _isConfirming = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = (constraints.maxWidth - _thumbSize - 8).clamp(
          0.0,
          double.infinity,
        );

        return SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onHorizontalDragUpdate: widget.enabled && !_isConfirming
                ? (details) {
                    setState(() {
                      _drag = (_drag + details.delta.dx).clamp(0.0, maxDrag);
                    });
                  }
                : null,
            onHorizontalDragEnd: widget.enabled && !_isConfirming
                ? (_) => _finishDrag(maxDrag)
                : null,
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.orange, Color(0xFFEB7B30)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    _isConfirming ? '正在确认' : '滑动确认已服用',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Positioned(
                    left: 4 + _drag,
                    child: Container(
                      width: _thumbSize,
                      height: _thumbSize,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: _isConfirming
                          ? const Padding(
                              padding: EdgeInsets.all(17),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.arrow_forward,
                              color: AppColors.orange,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _finishDrag(double maxDrag) async {
    if (_drag < maxDrag * _confirmThreshold) {
      setState(() => _drag = 0);
      return;
    }

    setState(() {
      _drag = maxDrag;
      _isConfirming = true;
    });

    try {
      await widget.onConfirmed();
    } finally {
      if (mounted) {
        setState(() => _isConfirming = false);
      }
    }
  }
}
