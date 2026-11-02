import 'package:flutter/material.dart';

class PttButton extends StatefulWidget {
  final bool enabled;
  final bool isActive;
  final bool isReceiving;
  final String targetName;
  final VoidCallback onPress;
  final VoidCallback onRelease;
  final VoidCallback? onCancel;

  const PttButton({
    super.key,
    required this.enabled,
    required this.isActive,
    required this.isReceiving,
    required this.targetName,
    required this.onPress,
    required this.onRelease,
    this.onCancel,
  });

  @override
  State<PttButton> createState() => _PttButtonState();
}

class _PttButtonState extends State<PttButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
    _rippleController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(PttButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _rippleController.repeat();
    } else if (!widget.isActive && oldWidget.isActive) {
      _rippleController.stop();
      _rippleController.reset();
    }
  }

  @override
  void dispose() {
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = !widget.enabled;
    Color bgColor;
    Color textColor;

    if (widget.isActive) {
      bgColor = const Color(0xFFDC2626);
      textColor = Colors.white;
    } else if (widget.isReceiving) {
      bgColor = const Color(0xFF047857);
      textColor = Colors.white;
    } else if (isDisabled) {
      bgColor = const Color(0xFF141628);
      textColor = Colors.white.withOpacity(0.3);
    } else {
      bgColor = const Color(0xFF3B82F6);
      textColor = Colors.white;
    }

    return GestureDetector(
      onTapDown: widget.enabled ? (_) => widget.onPress() : null,
      onTapUp: widget.enabled ? (_) => widget.onRelease() : null,
      onTapCancel: widget.enabled
          ? (widget.onCancel ?? widget.onRelease)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: widget.isActive || widget.isReceiving || isDisabled
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                ),
          color: bgColor,
          boxShadow: widget.isActive
              ? [
                  BoxShadow(
                    color: const Color(0x59EF4444),
                    blurRadius: 32,
                    offset: const Offset(0, 4),
                  ),
                ]
              : widget.isReceiving
                  ? [
                      BoxShadow(
                        color: const Color(0x4010B981),
                        blurRadius: 24,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : !isDisabled
                      ? [
                          BoxShadow(
                            color: const Color(0x333B82F6),
                            blurRadius: 24,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
          transform: widget.isActive
              ? Matrix4.identity()..scale(0.97)
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.isActive)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Color(0x59EF4444)
                        .withOpacity((1 - _rippleAnimation.value) * 0.8),
                    width: 3,
                  ),
                ),
                margin: EdgeInsets.all(-4 - _rippleAnimation.value * 10),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.isActive
                          ? '🔴'
                          : widget.isReceiving
                              ? '🔊'
                              : '🎙️',
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.isActive
                          ? 'Release'
                          : widget.isReceiving
                              ? '🔊 Listening'
                              : 'Hold to Talk',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  widget.isActive
                      ? 'Talking to ${widget.targetName}'
                      : widget.isReceiving
                          ? 'You can still hold to talk'
                          : widget.targetName.isNotEmpty
                              ? 'Hold to talk to ${widget.targetName}'
                              : 'Select a user first',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: textColor.withOpacity(0.7),
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
