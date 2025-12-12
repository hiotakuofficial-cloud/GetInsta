import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimationUtils {
  static Animation<Offset> createSlideAnimation({
    required AnimationController controller,
    Offset begin = const Offset(1, 0),
    Offset end = Offset.zero,
    Curve curve = Curves.easeOutCubic,
  }) {
    return Tween<Offset>(begin: begin, end: end).animate(
      CurvedAnimation(parent: controller, curve: curve),
    );
  }

  static Animation<double> createFadeAnimation({
    required AnimationController controller,
    double begin = 0.0,
    double end = 1.0,
    Curve curve = Curves.easeOut,
  }) {
    return Tween<double>(begin: begin, end: end).animate(
      CurvedAnimation(parent: controller, curve: curve),
    );
  }

  static Animation<double> createScaleAnimation({
    required AnimationController controller,
    double begin = 0.0,
    double end = 1.0,
    Curve curve = Curves.elasticOut,
  }) {
    return Tween<double>(begin: begin, end: end).animate(
      CurvedAnimation(parent: controller, curve: curve),
    );
  }

  static Animation<double> createRotationAnimation({
    required AnimationController controller,
    double begin = 0.0,
    double end = 1.0,
    Curve curve = Curves.easeInOut,
  }) {
    return Tween<double>(begin: begin, end: end).animate(
      CurvedAnimation(parent: controller, curve: curve),
    );
  }
}

class FadeInSlide extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset offset;
  final Curve curve;

  const FadeInSlide({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.delay = Duration.zero,
    this.offset = const Offset(0, 50),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    Future.delayed(widget.delay, () {
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
        return Transform.translate(
          offset: _slideAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class ScaleInFade extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double initialScale;
  final Curve curve;

  const ScaleInFade({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.delay = Duration.zero,
    this.initialScale = 0.8,
    this.curve = Curves.elasticOut,
  });

  @override
  State<ScaleInFade> createState() => _ScaleInFadeState();
}

class _ScaleInFadeState extends State<ScaleInFade>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _scaleAnimation = Tween<double>(
      begin: widget.initialScale,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    Future.delayed(widget.delay, () {
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
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class RotatingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  final Duration duration;

  const RotatingIcon({
    super.key,
    required this.icon,
    this.color = Colors.white,
    this.size = 24,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<RotatingIcon> createState() => _RotatingIconState();
}

class _RotatingIconState extends State<RotatingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
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
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: child,
        );
      },
      child: Icon(
        widget.icon,
        color: widget.color,
        size: widget.size,
      ),
    );
  }
}

class BouncingWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double bounceHeight;

  const BouncingWidget({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1000),
    this.bounceHeight = 10,
  });

  @override
  State<BouncingWidget> createState() => _BouncingWidgetState();
}

class _BouncingWidgetState extends State<BouncingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 0,
      end: widget.bounceHeight,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_animation.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class PulseAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;

  const PulseAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1000),
    this.minScale = 0.95,
    this.maxScale = 1.05,
  });

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class ShakeAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double offset;
  final bool start;

  const ShakeAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.offset = 10,
    this.start = false,
  });

  @override
  State<ShakeAnimation> createState() => _ShakeAnimationState();
}

class _ShakeAnimationState extends State<ShakeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: widget.offset), weight: 1),
      TweenSequenceItem(tween: Tween(begin: widget.offset, end: -widget.offset), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -widget.offset, end: widget.offset), weight: 2),
      TweenSequenceItem(tween: Tween(begin: widget.offset, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticIn,
    ));

    if (widget.start) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(ShakeAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.start && !oldWidget.start) {
      _controller.forward(from: 0);
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
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_animation.value, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class StaggeredAnimation extends StatefulWidget {
  final List<Widget> children;
  final Duration initialDelay;
  final Duration staggerDelay;
  final Axis direction;

  const StaggeredAnimation({
    super.key,
    required this.children,
    this.initialDelay = const Duration(milliseconds: 100),
    this.staggerDelay = const Duration(milliseconds: 100),
    this.direction = Axis.vertical,
  });

  @override
  State<StaggeredAnimation> createState() => _StaggeredAnimationState();
}

class _StaggeredAnimationState extends State<StaggeredAnimation> {
  @override
  Widget build(BuildContext context) {
    return widget.direction == Axis.vertical
        ? Column(
            children: List.generate(
              widget.children.length,
              (index) => FadeInSlide(
                delay: widget.initialDelay + (widget.staggerDelay * index),
                child: widget.children[index],
              ),
            ),
          )
        : Row(
            children: List.generate(
              widget.children.length,
              (index) => FadeInSlide(
                delay: widget.initialDelay + (widget.staggerDelay * index),
                offset: const Offset(50, 0),
                child: widget.children[index],
              ),
            ),
          );
  }
}
