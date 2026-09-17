import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class TopNotify {
  static void show(BuildContext context, String text, {bool success = true}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16,
        right: 16,
        child: _TopBanner(text: text, success: success, onDismiss: () => entry.remove()),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 5), () {
      if (entry.mounted) entry.remove();
    });
  }
}

class _TopBanner extends StatefulWidget {
  final String text;
  final bool success;
  final VoidCallback onDismiss;
  const _TopBanner({required this.text, required this.success, required this.onDismiss});
  @override
  State<_TopBanner> createState() => _TopBannerState();
}

class _TopBannerState extends State<_TopBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 350))..forward();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeTransition(
      opacity: CurvedAnimation(parent: _c, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween(begin: const Offset(0,-0.3), end: Offset.zero).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic)),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121A14) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: widget.success ? AppColors.brandNeon.withOpacity(0.6) : Colors.orange.withOpacity(0.6)),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16, offset: const Offset(0,6))],
            ),
            child: Row(children: [
              Icon(widget.success ? Icons.check_circle_rounded : Icons.info_rounded, color: widget.success ? AppColors.brandNeon : Colors.orange, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              GestureDetector(onTap: widget.onDismiss, child: const Icon(Icons.close_rounded, size: 18, color: Colors.grey)),
            ]),
          ),
        ),
      ),
    );
  }
}
