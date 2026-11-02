import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The logo palette continues into a calm navy background; decorative motion
/// stops for reduced motion, keyboard input, and when the app is not active.
class FamilyAuthLayout extends StatefulWidget {
  const FamilyAuthLayout(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.child,
      this.canGoBack = false});
  final String title, subtitle;
  final Widget child;
  final bool canGoBack;
  @override
  State<FamilyAuthLayout> createState() => _FamilyAuthLayoutState();
}

class _FamilyAuthLayoutState extends State<FamilyAuthLayout>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController motion;
  bool resumed = true;
  @override
  void initState() {
    super.initState();
    motion =
        AnimationController(vsync: this, duration: const Duration(seconds: 22));
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    resumed = state == AppLifecycleState.resumed;
    syncMotion();
  }

  void syncMotion() {
    if (!mounted) return;
    final media = MediaQuery.of(context);
    final allowed = resumed &&
        TickerMode.valuesOf(context).enabled &&
        !media.disableAnimations &&
        !media.accessibleNavigation &&
        media.viewInsets.bottom == 0;
    if (allowed && !motion.isAnimating) motion.repeat();
    if (!allowed) motion.stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        ColorScheme.fromSeed(seedColor: const Color(0xFF059BB1)).copyWith(
      primary: const Color(0xFF056A7B),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFD8F4F2),
      onPrimaryContainer: const Color(0xFF063D49),
      surface: Colors.white,
      onSurface: const Color(0xFF173C48),
    );
    return Theme(
        data: Theme.of(context).copyWith(colorScheme: colors),
        child: Scaffold(
          backgroundColor: const Color(0xFF070F20),
          appBar: widget.canGoBack
              ? AppBar(
                  title: const Text('عائلتك في عيونك'),
                  backgroundColor: const Color(0xFF070F20),
                  foregroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent)
              : null,
          body: Stack(fit: StackFit.expand, children: [
            const DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF070F20), Color(0xFF10374B), Color(0xFF075C62)],
            ))),
            IgnorePointer(
                child: ExcludeSemantics(
                    child: LayoutBuilder(
                        builder: (_, bounds) => AnimatedBuilder(
                            animation: motion,
                            builder: (_, child) => Stack(children: [
                                  for (var i = 0; i < 9; i++)
                                    Positioned(
                                      left: bounds.maxWidth *
                                              ((i * .137 + .06) % .92) +
                                          math.sin((motion.value + i / 9) *
                                                  math.pi *
                                                  2) *
                                              18,
                                      top: bounds.maxHeight *
                                          (1.08 -
                                              ((motion.value + i / 9) % 1) *
                                                  1.18),
                                      child: Transform.rotate(
                                          angle: math.sin(
                                                  motion.value * math.pi * 2 +
                                                      i) *
                                              .22,
                                          child: Icon(
                                              const [
                                                Icons.favorite_outline,
                                                Icons.star_outline_rounded,
                                                Icons.cloud_outlined,
                                                Icons.auto_awesome_outlined,
                                                Icons.home_outlined
                                              ][i % 5],
                                              size: 20.0 + (i % 3) * 10,
                                              color: (i.isEven
                                                      ? const Color(0xFF6EE9D4)
                                                      : const Color(0xFF75D6FF))
                                                  .withValues(alpha: .16))),
                                    ),
                                ]))))),
            SafeArea(
                child: Center(
                    child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: const Color(0xFF060C19),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                                color: const Color(0xFF53D8D0)
                                    .withValues(alpha: .3)),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x2400D5E7), blurRadius: 32)
                            ]),
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset('assets/brand/eyoonak-logo.png',
                                width: 84,
                                height: 84,
                                semanticLabel: 'شعار عيونك'))),
                    const SizedBox(height: 18),
                    Text(widget.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(widget.subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xFFD0EBF0), height: 1.7)),
                    const SizedBox(height: 24),
                    Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: const Color(0xFFD4EDF1)),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x33030B18),
                                  blurRadius: 28,
                                  offset: Offset(0, 10))
                            ]),
                        child: widget.child),
                    const SizedBox(height: 18),
                    const Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Icon(Icons.home_rounded,
                              color: Color(0xFF91F0DB), size: 18),
                          Text('نتعلم سوا… ونكبر بمحبة',
                              style: TextStyle(color: Color(0xFFD0EBF0)))
                        ]),
                  ])),
            ))),
          ]),
        ));
  }
}
