import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Original cartoon companion. Idle motion pauses with the surrounding route.
class FamilyMascot extends StatefulWidget {
  const FamilyMascot({super.key, this.size = 120});
  final double size;
  @override
  State<FamilyMascot> createState() => _FamilyMascotState();
}

class _FamilyMascotState extends State<FamilyMascot> with TickerProviderStateMixin {
  late final idle = AnimationController(vsync: this, duration: const Duration(seconds: 4));
  late final wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  bool greeting = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) || !TickerMode.valuesOf(context).enabled) {
      idle.stop();
    } else if (!idle.isAnimating) {
      idle.repeat();
    }
  }

  void hello() {
    setState(() => greeting = !greeting);
    if (!MediaQuery.disableAnimationsOf(context)) wave.forward(from: 0);
  }

  @override
  void dispose() {
    idle.dispose();
    wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: greeting ? 'عيوني يقول: أنت بطل! اضغط لتحيته' : 'عيوني، صديق العائلة. اضغط حتى يلوح لك',
        button: true,
        child: Tooltip(
            message: greeting ? 'أنت بطل! 🌟' : 'هلا يا صديقي!',
            child: InkWell(
              borderRadius: BorderRadius.circular(32),
              onTap: hello,
              child: SizedBox(
                  width: widget.size,
                  height: widget.size + 24,
                  child: Column(children: [
                    Expanded(
                        child: RepaintBoundary(
                            child: AnimatedBuilder(
                      animation: Listenable.merge([idle, wave]),
                      builder: (context, child) => CustomPaint(
                          size: Size.square(widget.size), painter: _MascotPainter(idle.value, wave.value, greeting)),
                    ))),
                    Text(greeting ? 'أنت بطل! 🌟' : 'أنا عيوني 👋',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ])),
            )),
      );
}

class _MascotPainter extends CustomPainter {
  _MascotPainter(this.phase, this.wave, this.happy);
  final double phase, wave;
  final bool happy;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 160, size.height / 160);
    final bob = math.sin(phase * math.pi * 2) * 3;
    final paint = Paint();
    void oval(Rect r, Color c) {
      paint.color = c;
      canvas.drawOval(r, paint);
    }

    oval(const Rect.fromLTWH(35, 140, 90, 9), const Color(0x18004444));
    canvas.translate(0, bob);
    oval(const Rect.fromLTWH(42, 130, 25, 12), const Color(0xffffb86c));
    oval(const Rect.fromLTWH(93, 130, 25, 12), const Color(0xffffb86c));
    canvas.save();
    canvas.translate(30, 88);
    canvas.rotate(-.35 - math.sin(wave * math.pi * 6) * .65);
    oval(const Rect.fromLTWH(-15, -30, 28, 62), const Color(0xff239b9c));
    canvas.restore();
    oval(const Rect.fromLTWH(116, 67, 28, 58), const Color(0xff239b9c));
    paint.color = const Color(0xff39bbb4);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(28, 20, 104, 116), const Radius.circular(48)), paint);
    oval(const Rect.fromLTWH(46, 84, 68, 46), const Color(0xffbcf3de));
    final blink = phase > .93 && phase < .97;
    for (final x in [54.0, 103.0]) {
      oval(Rect.fromCenter(center: Offset(x, 62), width: 47, height: blink ? 5 : 51), Colors.white);
      if (!blink) {
        oval(Rect.fromCenter(center: Offset(x + 3, 64), width: 23, height: 29), const Color(0xff204b59));
        oval(Rect.fromLTWH(x + 2, 54, 7, 9), Colors.white);
      }
    }
    oval(const Rect.fromLTWH(33, 85, 19, 10), const Color(0xffffb7b2));
    oval(const Rect.fromLTWH(110, 85, 19, 10), const Color(0xffffb7b2));
    paint.color = const Color(0xffffbd73);
    canvas.drawPath(
        Path()
          ..moveTo(70, 79)
          ..quadraticBezierTo(80, 72, 90, 79)
          ..quadraticBezierTo(80, 98, 70, 79),
        paint);
    paint
      ..color = const Color(0xff32616a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(const Rect.fromLTWH(66, 92, 28, 18), .1, math.pi - .2, false, paint);
    paint.style = PaintingStyle.fill;
    if (happy) {
      for (var i = 0; i < 5; i++) {
        final a = i * math.pi * 2 / 5;
        oval(Rect.fromCircle(center: Offset(80 + math.cos(a) * 68, 76 + math.sin(a) * 65), radius: 4),
            const Color(0xffffcc58));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MascotPainter old) => old.phase != phase || old.wave != wave || old.happy != happy;
}
