import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'family_mascot.dart';

/// Shared family motion. System reduced-motion preferences take priority.
class FamilyReveal extends StatefulWidget {
  const FamilyReveal({super.key, required this.child});
  final Widget child;
  @override
  State<FamilyReveal> createState() => _FamilyRevealState();
}

class _FamilyRevealState extends State<FamilyReveal> {
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
              offset: Offset(0, 18 * (1 - value)), child: child)),
      child: widget.child,
    );
  }
}

Future<void> showFamilySuccess(BuildContext context) async {
  AudioPlayer? player;
  try {
    player = AudioPlayer();
    final audio = player;
    unawaited(() async {
      try {
        await HapticFeedback.lightImpact();
        await audio.setAsset('assets/audio/success.wav');
        await audio.setVolume(.35);
        await audio.play();
      } catch (_) {}
    }());
  } catch (_) {}
  try {
    if (context.mounted) { await showDialog<void>(context: context, builder: (_) => const FamilyCelebration()); }
  } finally {
    try {
      await player?.dispose();
    } catch (_) {}
  }
}

class FamilyConfettiPainter extends CustomPainter {
  FamilyConfettiPainter(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    const colors = [
      Colors.pink,
      Colors.blue,
      Colors.amber,
      Colors.teal,
      Colors.orange
    ];
    for (var i = 0; i < 32; i++) {
      final angle = (i * 2.399);
      final distance = progress * (45 + (i % 6) * 17);
      final x = size.width / 2 + math.cos(angle) * distance;
      final y = size.height * .52 +
          math.sin(angle) * distance +
          80 * progress * progress;
      final paint = Paint()
        ..color = colors[i % colors.length]
            .withValues(alpha: (1 - progress * .75).clamp(0, 1));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle + progress * 4);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(-3, -5, 6, 10), const Radius.circular(1)),
          paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(FamilyConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class FamilyCelebration extends StatelessWidget {
  const FamilyCelebration({super.key});
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: const Text('أحسنت يا بطل! 🌟', textAlign: TextAlign.center),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
            height: 180,
            width: 240,
            child: TweenAnimationBuilder<double>(
                tween: Tween(begin: reduced ? 1 : 0, end: 1),
                duration: Duration(milliseconds: reduced ? 0 : 1400),
                builder: (_, v, child) =>
                    Stack(fit: StackFit.expand, children: [
                      if (!reduced)
                        CustomPaint(painter: FamilyConfettiPainter(v)),
                      Center(child: child)
                    ]),
                child: const FamilyMascot(size: 150))),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: reduced ? 1 : 0, end: 1),
          duration: Duration(milliseconds: reduced ? 0 : 900),
          builder: (_, v, child) => Transform.translate(
              offset: Offset(0, -12 * v),
              child: Opacity(opacity: v.clamp(0, 1), child: child)),
          child:
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.star_rounded, color: Colors.amber, size: 26),
            Icon(Icons.star_rounded, color: Colors.orange, size: 36),
            Icon(Icons.star_rounded, color: Colors.amber, size: 26)
          ]),
        ),
        const SizedBox(height: 16),
        const Text('إنجاز جميل اليوم. عيوني يفرح بكل خطوة تسويها!',
            textAlign: TextAlign.center),
      ]),
      actions: [
        FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('نكمل المشوار'))
      ],
    );
  }
}

class FamilyHero extends StatelessWidget {
  const FamilyHero(
      {super.key,
      required this.title,
      required this.subtitle,
      this.playful = true});
  final String title, subtitle;
  final bool playful;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
              colors: [colors.primaryContainer, colors.tertiaryContainer])),
      child: Row(children: [
        if (playful)
          const FamilyMascot(size: 104)
        else
          Icon(Icons.home_outlined, size: 42, color: colors.onPrimaryContainer),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: colors.onPrimaryContainer))
        ]))
      ]),
    );
    return FamilyReveal(child: content);
  }
}
