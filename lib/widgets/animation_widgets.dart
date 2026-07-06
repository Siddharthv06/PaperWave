import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'sketchy_container.dart';

// --- ROTATING VINYL WITH SMOOTH START/STOP ---
class RotatingVinyl extends StatefulWidget {
  final Widget child;
  final bool isPlaying;
  final double size;
  final double rotationSpeedSeconds;

  const RotatingVinyl({
    super.key,
    required this.child,
    required this.isPlaying,
    required this.size,
    this.rotationSpeedSeconds = 8.0,
  });

  @override
  State<RotatingVinyl> createState() => _RotatingVinylState();
}

class _RotatingVinylState extends State<RotatingVinyl> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _currentSpeed = 0.0; // Multiplier: 0.0 -> 1.0
  double _turns = 0.0;
  Duration _lastElapsed = Duration.zero;
  final ValueNotifier<double> _turnsNotifier = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (widget.isPlaying) {
      _currentSpeed = 1.0;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }
    final double dt = (elapsed.inMicroseconds - _lastElapsed.inMicroseconds) / 1000000.0;
    _lastElapsed = elapsed;

    final double targetMultiplier = widget.isPlaying ? 1.0 : 0.0;
    if ((_currentSpeed - targetMultiplier).abs() < 0.005) {
      _currentSpeed = targetMultiplier;
    } else {
      _currentSpeed += (targetMultiplier - _currentSpeed) * 0.05; // smooth damping
    }

    if (_currentSpeed > 0.0) {
      final double turnsPerSecond = 1.0 / widget.rotationSpeedSeconds;
      _turns = (_turns + turnsPerSecond * _currentSpeed * dt) % 1.0;
      _turnsNotifier.value = _turns;
    } else if (!widget.isPlaying && _currentSpeed == 0.0) {
      _ticker.stop();
      _lastElapsed = Duration.zero;
    }
  }

  @override
  void didUpdateWidget(covariant RotatingVinyl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        if (!_ticker.isActive) {
          _lastElapsed = Duration.zero;
          _ticker.start();
        }
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _turnsNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _turnsNotifier,
      builder: (context, turns, child) {
        return RotationTransition(
          turns: AlwaysStoppedAnimation(turns),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// --- SMOOTH SLIDER WITH DYNAMIC THUMB ---
class SmoothSlider extends StatefulWidget {
  final double value;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final Color activeColor;
  final Color inactiveColor;
  final double normalThumbRadius;
  final double activeThumbRadius;
  final double trackHeight;

  const SmoothSlider({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    required this.activeColor,
    required this.inactiveColor,
    this.normalThumbRadius = 8.0,
    this.activeThumbRadius = 12.0,
    this.trackHeight = 4.0,
  });

  @override
  State<SmoothSlider> createState() => _SmoothSliderState();
}

class _SmoothSliderState extends State<SmoothSlider> {
  bool _isDragging = false;
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final double displayValue = _isDragging ? (_dragValue ?? widget.value) : widget.value;

    return TweenAnimationBuilder<double>(
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 250),
      tween: Tween<double>(begin: displayValue, end: displayValue),
      curve: Curves.linear,
      builder: (context, animatedValue, child) {
        return SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: widget.trackHeight,
            activeTrackColor: widget.activeColor,
            inactiveTrackColor: widget.inactiveColor,
            thumbColor: widget.activeColor,
            thumbShape: RoundSliderThumbShape(
              enabledThumbRadius: _isDragging ? widget.activeThumbRadius : widget.normalThumbRadius,
            ),
            overlayColor: widget.activeColor.withValues(alpha: 0.12),
          ),
          child: Slider(
            min: 0.0,
            max: widget.max > 0 ? widget.max : 1.0,
            value: animatedValue.clamp(0.0, widget.max > 0 ? widget.max : 1.0),
            onChangeStart: (val) {
              setState(() {
                _isDragging = true;
                _dragValue = val;
              });
              widget.onChangeStart?.call(val);
            },
            onChanged: (val) {
              setState(() {
                _dragValue = val;
              });
              widget.onChanged(val);
            },
            onChangeEnd: (val) {
              setState(() {
                _isDragging = false;
                _dragValue = null;
              });
              widget.onChangeEnd?.call(val);
            },
          ),
        );
      },
    );
  }
}

// --- TACTILE PRESSABLE CARD & BUTTON WRAPPER ---
class TactileButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final double borderWidth;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final Offset shadowOffset;
  final bool hasPencilShading;
  final double pressedScale;

  const TactileButton({
    super.key,
    required this.child,
    required this.onTap,
    this.backgroundColor,
    this.borderWidth = 1.5,
    required this.borderRadius,
    this.padding = const EdgeInsets.all(8),
    this.shadowOffset = const Offset(2, 2),
    this.hasPencilShading = true,
    this.pressedScale = 0.92,
  });

  @override
  State<TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<TactileButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _shadowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.pressedScale).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _shadowAnimation = Tween<Offset>(
      begin: widget.shadowOffset,
      end: widget.shadowOffset * 0.25, // shadow decreases slightly
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(covariant TactileButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shadowOffset != oldWidget.shadowOffset) {
      _shadowAnimation = Tween<Offset>(
        begin: widget.shadowOffset,
        end: widget.shadowOffset * 0.25,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _controller.forward();
      },
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: SketchyContainer(
              backgroundColor: widget.backgroundColor,
              borderWidth: widget.borderWidth,
              borderRadius: widget.borderRadius,
              padding: widget.padding,
              shadowOffset: _shadowAnimation.value,
              hasPencilShading: widget.hasPencilShading,
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

// --- POP LIKE HEART BUTTON ---
class HeartLikeButton extends StatefulWidget {
  final bool isLiked;
  final VoidCallback onTap;
  final Color iconColor;
  final Color activeColor;
  final double size;

  const HeartLikeButton({
    super.key,
    required this.isLiked,
    required this.onTap,
    required this.iconColor,
    this.activeColor = Colors.redAccent,
    this.size = 24,
  });

  @override
  State<HeartLikeButton> createState() => _HeartLikeButtonState();
}

class _HeartLikeButtonState extends State<HeartLikeButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  bool _sparkleActive = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.2), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _rotateAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.087), weight: 30), // ~5 deg
      TweenSequenceItem(tween: Tween<double>(begin: 0.087, end: -0.05), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: -0.05, end: 0.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(covariant HeartLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLiked && !oldWidget.isLiked) {
      _controller.forward(from: 0.0);
      HapticFeedback.mediumImpact();
      setState(() {
        _sparkleActive = true;
      });
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          setState(() {
            _sparkleActive = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!widget.isLiked) {
          _controller.forward(from: 0.0);
        } else {
          HapticFeedback.lightImpact();
        }
        widget.onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (_sparkleActive)
            CustomPaint(
              size: Size(widget.size * 2.2, widget.size * 2.2),
              painter: SparklePainter(color: widget.activeColor),
            ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Transform.rotate(
                  angle: _rotateAnimation.value,
                  child: Icon(
                    widget.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: widget.isLiked ? widget.activeColor : widget.iconColor,
                    size: widget.size,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class SparklePainter extends CustomPainter {
  final Color color;
  SparklePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final rMin = size.width * 0.38;
    final rMax = size.width * 0.62;

    const count = 6;
    for (int i = 0; i < count; i++) {
      final angle = (i * 2 * math.pi) / count;
      final start = Offset(
        center.dx + rMin * math.cos(angle),
        center.dy + rMin * math.sin(angle),
      );
      final end = Offset(
        center.dx + rMax * math.cos(angle),
        center.dy + rMax * math.sin(angle),
      );
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- FADE & SLIDE UP ENTRANCE (FOR MODE CARDS) ---
class FadeSlideEntrance extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const FadeSlideEntrance({
    super.key,
    required this.child,
    required this.delay,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<FadeSlideEntrance> createState() => _FadeSlideEntranceState();
}

class _FadeSlideEntranceState extends State<FadeSlideEntrance> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _slideAnimation = Tween<double>(begin: 25.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// --- STAGGERED CHECKBOX ENTRANCE ---
class StaggeredCheckboxEntrance extends StatefulWidget {
  final Widget child;
  final int index;

  const StaggeredCheckboxEntrance({
    super.key,
    required this.child,
    required this.index,
  });

  @override
  State<StaggeredCheckboxEntrance> createState() => _StaggeredCheckboxEntranceState();
}

class _StaggeredCheckboxEntranceState extends State<StaggeredCheckboxEntrance> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _slide = Tween<double>(begin: -20.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    Future.delayed(Duration(milliseconds: widget.index * 50), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(_slide.value, 0.0),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// --- SHIMMER GRADIENT LOADER ---
class ShimmerPlaceholder extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const ShimmerPlaceholder({
    super.key,
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2B2B30) : const Color(0xFFE9E5DE);
    final highlightColor = isDark ? const Color(0xFF38383D) : const Color(0xFFF3EFE9);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.3, 0.5, 0.7],
              transform: _SlidingGradientTransform(slidePercent: _controller.value),
            ),
          ),
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final double width = bounds.width;
    final double translation = -width + (2 * width * slidePercent);
    return Matrix4.translationValues(translation, 0, 0);
  }
}

// --- SKELETON SONG LIST FOR LOADING ---
class SkeletonSongList extends StatelessWidget {
  const SkeletonSongList({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      itemCount: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: SketchyContainer(
            backgroundColor: isDark ? const Color(0xFF26262B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            padding: const EdgeInsets.all(12.0),
            shadowOffset: const Offset(2.0, 2.0),
            child: Row(
              children: [
                ShimmerPlaceholder(
                  width: 46,
                  height: 46,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerPlaceholder(
                        width: MediaQuery.of(context).size.width * 0.45,
                        height: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                      ShimmerPlaceholder(
                        width: MediaQuery.of(context).size.width * 0.28,
                        height: 10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// --- SPINNING VINYL LOADER ---
class RotatingVinylLoader extends StatefulWidget {
  final double size;
  const RotatingVinylLoader({super.key, this.size = 64.0});

  @override
  State<RotatingVinylLoader> createState() => _RotatingVinylLoaderState();
}

class _RotatingVinylLoaderState extends State<RotatingVinylLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final frameColor = isDark ? const Color(0xFFFAF6EE) : const Color(0xFF18181A);

    return RotationTransition(
      turns: _controller,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F10),
          shape: BoxShape.circle,
          border: Border.all(color: frameColor, width: 2.0),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(widget.size, widget.size),
              painter: VinylGroovesPainter(
                lineColor: isDark ? Colors.white30 : Colors.grey.withValues(alpha: 0.4),
              ),
            ),
            Container(
              width: widget.size * 0.3,
              height: widget.size * 0.3,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B1C1E) : const Color(0xFFFAF6EE),
                shape: BoxShape.circle,
                border: Border.all(color: frameColor, width: 1.5),
              ),
              child: const Icon(Icons.music_note, size: 10, color: Colors.grey),
            ),
            Container(
              width: widget.size * 0.08,
              height: widget.size * 0.08,
              decoration: BoxDecoration(
                color: frameColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VinylGroovesPainter extends CustomPainter {
  final Color lineColor;
  VinylGroovesPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(w / 2, w / 2);

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, w * 0.44, paint);
    canvas.drawCircle(center, w * 0.37, paint);
    canvas.drawCircle(center, w * 0.30, paint);
    canvas.drawCircle(center, w * 0.23, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- FLOATING NOTES OVERLAY WIDGET ---
class FloatingNotesOverlay extends StatefulWidget {
  final bool isPlaying;
  final Widget child;

  const FloatingNotesOverlay({
    super.key,
    required this.isPlaying,
    required this.child,
  });

  @override
  State<FloatingNotesOverlay> createState() => _FloatingNotesOverlayState();
}

class _FloatingNotesOverlayState extends State<FloatingNotesOverlay> with TickerProviderStateMixin {
  final List<_FloatingNote> _notes = [];
  Timer? _timer;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    if (widget.isPlaying) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(covariant FloatingNotesOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _startTimer();
      } else {
        _stopTimer();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 9), (timer) {
      _spawnNotes();
    });
    _spawnNotes();
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _spawnNotes() {
    if (!mounted) return;
    final count = _random.nextInt(3) + 2; // 2-4 notes
    for (int i = 0; i < count; i++) {
      final double startX = 0.2 + _random.nextDouble() * 0.6; // spawn away from side edges
      final double durationMs = 3500 + _random.nextDouble() * 2000;
      final double scale = 0.7 + _random.nextDouble() * 0.5;
      final double drift = (_random.nextDouble() - 0.5) * 80;
      final IconData icon = _random.nextBool() ? Icons.music_note : Icons.music_video;

      final controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: durationMs.toInt()),
      );

      final note = _FloatingNote(
        startX: startX,
        scale: scale,
        drift: drift,
        icon: icon,
        controller: controller,
      );

      setState(() {
        _notes.add(note);
      });

      controller.forward().then((_) {
        if (mounted) {
          setState(() {
            _notes.remove(note);
          });
        }
        controller.dispose();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final note in _notes) {
      note.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ponytail: skip particle system on web — AnimationControllers per note kill canvas perf
    if (kIsWeb) return widget.child;

    return Stack(
      children: [
        widget.child,
        ..._notes.map((note) {
          return AnimatedBuilder(
            animation: note.controller,
            builder: (context, child) {
              final double t = note.controller.value;
              final double yPos = (1.0 - t) * MediaQuery.of(context).size.height * 0.7 + 
                  MediaQuery.of(context).size.height * 0.15;
              final double xPos = note.startX * MediaQuery.of(context).size.width +
                  math.sin(t * 2.5 * math.pi) * 24 + 
                  t * note.drift;

              final opacity = (t < 0.15)
                  ? (t / 0.15)
                  : (t > 0.8)
                      ? ((1.0 - t) / 0.2)
                      : 1.0;

              return Positioned(
                left: xPos.clamp(16, MediaQuery.of(context).size.width - 36),
                top: yPos,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: note.scale,
                    child: Icon(
                      note.icon,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white24
                          : Colors.black26,
                      size: 20,
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }
}

class _FloatingNote {
  final double startX;
  final double scale;
  final double drift;
  final IconData icon;
  final AnimationController controller;

  _FloatingNote({
    required this.startX,
    required this.scale,
    required this.drift,
    required this.icon,
    required this.controller,
  });
}

// --- ICON TAP ROTATE INTERACTION ---
class AnimatedTapIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const AnimatedTapIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
  });

  @override
  State<AnimatedTapIcon> createState() => _AnimatedTapIconState();
}

class _AnimatedTapIconState extends State<AnimatedTapIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _rotationAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.18), weight: 50), // rotate slightly
      TweenSequenceItem(tween: Tween<double>(begin: 0.18, end: 0.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _controller.forward(from: 0.0);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.rotate(
            angle: _rotationAnimation.value,
            child: Icon(widget.icon, color: widget.color, size: widget.size),
          );
        },
      ),
    );
  }
}


// --- SCRIBBLE ENTRANCE (Card border drawn like a pen, then content fades in) ---
class ScribbleEntrance extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Color borderColor;
  final double borderWidth;
  final BorderRadius borderRadius;

  const ScribbleEntrance({
    super.key,
    required this.child,
    required this.borderColor,
    this.delay = Duration.zero,
    this.borderWidth = 2.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  State<ScribbleEntrance> createState() => _ScribbleEntranceState();
}

class _ScribbleEntranceState extends State<ScribbleEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  static const double _borderEnd = 0.72;
  static const double _contentStart = 0.62;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final borderProgress = (t / _borderEnd).clamp(0.0, 1.0);
        final contentOpacity =
            ((t - _contentStart) / (1.0 - _contentStart)).clamp(0.0, 1.0);
        return Stack(
          fit: StackFit.passthrough,
          children: [
            Opacity(opacity: contentOpacity, child: child),
            if (borderProgress < 1.0)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: ScribbleBorderPainter(
                      progress: borderProgress,
                      color: widget.borderColor,
                      borderWidth: widget.borderWidth,
                      borderRadius: widget.borderRadius,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

class ScribbleBorderPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double borderWidth;
  final BorderRadius borderRadius;

  ScribbleBorderPainter({
    required this.progress,
    required this.color,
    required this.borderWidth,
    required this.borderRadius,
  });

  final _rng = math.Random(42);

  Path _buildSketchyBorderPath(Size size) {
    final w = size.width;
    final h = size.height;
    const r = 16.0;
    final path = Path();
    double j() => (_rng.nextDouble() - 0.5) * 1.2;
    path.moveTo(r + j(), j());
    for (double x = r; x < w - r; x += 16) { path.lineTo(x + j(), j()); }
    path.quadraticBezierTo(w + j(), j(), w + j(), r + j());
    for (double y = r; y < h - r; y += 16) { path.lineTo(w + j(), y + j()); }
    path.quadraticBezierTo(w + j(), h + j(), w - r + j(), h + j());
    for (double x = w - r; x > r; x -= 16) { path.lineTo(x + j(), h + j()); }
    path.quadraticBezierTo(j(), h + j(), j(), h - r + j());
    for (double y = h - r; y > r; y -= 16) { path.lineTo(j(), y + j()); }
    path.quadraticBezierTo(j(), j(), r + j(), j());
    path.close();
    return path;
  }

  void _drawPartial(Canvas canvas, Path path, Paint paint) {
    if (progress <= 0) return;
    if (progress >= 1.0) { canvas.drawPath(path, paint); return; }
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * progress), paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildSketchyBorderPath(size);
    final p1 = Paint()
      ..color = color ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final p2 = Paint()
      ..color = color.withValues(alpha: 0.72) ..strokeWidth = borderWidth * 0.75
      ..style = PaintingStyle.stroke ..strokeCap = StrokeCap.round;
    final p3 = Paint()
      ..color = color.withValues(alpha: 0.42) ..strokeWidth = borderWidth * 0.55
      ..style = PaintingStyle.stroke ..strokeCap = StrokeCap.round;
    _drawPartial(canvas, path, p1);
    canvas.save(); canvas.translate(0.8, -0.6); _drawPartial(canvas, path, p2); canvas.restore();
    canvas.save(); canvas.translate(-0.7, 0.9); _drawPartial(canvas, path, p3); canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ScribbleBorderPainter old) =>
      old.progress != progress || old.color != color;
}