import 'package:flutter/material.dart';

class NotificationHelper {
  static void show(BuildContext context, String message, {bool isError = false, bool isWarning = false}) {
    // Warna tema
    final Color bgColor = isError 
        ? const Color(0xFFC62828) 
        : (isWarning ? const Color(0xFF455A64) : const Color(0xFF2E7D32));
    
    final IconData icon = isError 
        ? Icons.error_outline_rounded 
        : (isWarning ? Icons.info_outline_rounded : Icons.check_circle_outline_rounded);

    final overlay = Overlay.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: topPadding + 10,
        left: 16,
        right: 16,
        child: _NotificationWidget(
          message: message,
          bgColor: bgColor,
          icon: icon,
          title: isError ? 'Oops!' : (isWarning ? 'Informasi' : 'Berhasil'),
          onDismiss: () => overlayEntry.remove(),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Otomatis hapus setelah 3 detik (atau 6 detik jika error agar sempat terbaca)
    Future.delayed(Duration(seconds: isError ? 6 : 3), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }
}

class _NotificationWidget extends StatelessWidget {
  final String message;
  final Color bgColor;
  final IconData icon;
  final String title;
  final VoidCallback onDismiss;

  const _NotificationWidget({
    required this.message,
    required this.bgColor,
    required this.icon,
    required this.title,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Dismissible(
        key: UniqueKey(),
        direction: DismissDirection.up,
        onDismissed: (_) => onDismiss(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                onPressed: onDismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
