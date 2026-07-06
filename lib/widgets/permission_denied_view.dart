import 'package:flutter/material.dart';
import 'sketchy_container.dart';

class PermissionDeniedView extends StatelessWidget {
  final VoidCallback onGrantAccess;
  final VoidCallback onPlayDemo;

  const PermissionDeniedView({
    super.key,
    required this.onGrantAccess,
    required this.onPlayDemo,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFFAF6EE) : const Color(0xFF18181A);
    final subtitleColor = isDark ? Colors.white60 : Colors.black54;
    final btnBg = isDark ? const Color(0xFF333338) : Colors.white;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SketchyContainer(
          backgroundColor: isDark ? const Color(0xFF26262B) : const Color(0xFFFFFDF9),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF5C2D2D) : const Color(0xFFFFD1D1), 
                  border: Border.all(color: textColor, width: 1.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(Icons.security, size: 48, color: isDark ? const Color(0xFFFAF6EE) : const Color(0xFF18181A)),
              ),
              const SizedBox(height: 16),
              Text(
                'Permission Denied',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We need access to your device storage to scan and play your offline music files.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: subtitleColor,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: onGrantAccess,
                child: SketchyContainer(
                  backgroundColor: isDark ? const Color(0xFF3B5C5C) : const Color(0xFFC4E8E8), 
                  borderWidth: 1.8,
                  borderRadius: BorderRadius.circular(8),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shadowOffset: const Offset(2, 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.settings, size: 18, color: isDark ? const Color(0xFFC4E8E8) : const Color(0xFF18181A)),
                      const SizedBox(width: 8),
                      Text(
                        'Grant Access',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFFC4E8E8) : const Color(0xFF18181A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: onPlayDemo,
                child: SketchyContainer(
                  backgroundColor: btnBg,
                  borderWidth: 1.8,
                  borderRadius: BorderRadius.circular(8),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shadowOffset: const Offset(2, 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_queue, size: 18, color: textColor),
                      const SizedBox(width: 8),
                      Text(
                        'Play Online Demo Tracks',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
