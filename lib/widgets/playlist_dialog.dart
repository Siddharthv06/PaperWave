import 'package:flutter/material.dart';
import 'sketchy_container.dart';

class PlaylistDialog extends StatefulWidget {
  const PlaylistDialog({super.key});

  @override
  State<PlaylistDialog> createState() => _PlaylistDialogState();
}

class _PlaylistDialogState extends State<PlaylistDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFFAF6EE) : const Color(0xFF18181A);
    final hintColor = isDark ? Colors.white38 : Colors.black38;
    final inputBg = isDark ? const Color(0xFF333338) : Colors.white;
    final cancelBg = isDark ? const Color(0xFF333338) : Colors.white;
    final createBg = isDark ? const Color(0xFF3B5C3B) : const Color(0xFFB4E3B4);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: SketchyContainer(
        backgroundColor: isDark ? const Color(0xFF26262B) : const Color(0xFFFFFDF9),
        padding: const EdgeInsets.all(20.0),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create Playlist',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            SketchyContainer(
              backgroundColor: inputBg,
              borderWidth: 1.5,
              borderRadius: BorderRadius.circular(8),
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              shadowOffset: const Offset(2, 2),
              child: TextField(
                controller: _controller,
                autofocus: true,
                style: TextStyle(fontFamily: 'monospace', color: textColor),
                decoration: InputDecoration(
                  hintText: 'Enter playlist name...',
                  hintStyle: TextStyle(fontFamily: 'monospace', color: hintColor),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: SketchyContainer(
                    backgroundColor: cancelBg,
                    borderWidth: 1.5,
                    borderRadius: BorderRadius.circular(8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shadowOffset: const Offset(2, 2),
                    child: Text(
                      'Cancel',
                      style: TextStyle(fontFamily: 'monospace', color: textColor),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    final text = _controller.text.trim();
                    if (text.isNotEmpty) {
                      Navigator.pop(context, text);
                    }
                  },
                  child: SketchyContainer(
                    backgroundColor: createBg,
                    borderWidth: 1.5,
                    borderRadius: BorderRadius.circular(8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shadowOffset: const Offset(2, 2),
                    child: Text(
                      'Create',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFFAF6EE) : const Color(0xFF18181A),
                      ),
                    ),
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
