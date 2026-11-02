import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'startup_intro.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? video;
  Timer? deadline;
  bool ready = false, started = false;
  void finish() {
    if (mounted) ref.read(startupIntroCompleteProvider.notifier).state = true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    deadline = Timer(const Duration(seconds: 6), finish);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => finish());
      return;
    }
    final c = VideoPlayerController.asset('assets/brand/eyoonak-intro.mp4');
    video = c;
    c.addListener(() {
      if (c.value.isInitialized &&
          c.value.position >= c.value.duration &&
          c.value.duration > Duration.zero) {
        finish();
      }
    });
    unawaited(() async {
      try {
        await c.initialize();
        await c.setVolume(0);
        await c.setLooping(false);
        if (!mounted) return;
        setState(() => ready = true);
        await c.play();
      } catch (_) {
        finish();
      }
    }());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      video?.pause();
    } else if (!ref.read(startupIntroCompleteProvider)) {
      video?.play();
    }
  }

  @override
  void dispose() {
    deadline?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = ref.watch(startupIntroCompleteProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: const Color(0xFF070F1C)),
        child: Scaffold(
          backgroundColor: const Color(0xFF070F1C),
          body: ready && !done
              ? SplashVideoViewport(
                  sourceSize: video!.value.size, child: VideoPlayer(video!))
              : Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Image.asset('assets/brand/eyoonak-logo.png', width: 150),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(color: Colors.white),
                ])),
        ));
  }
}

/// This asset is a landscape export containing a centered 9:16 portrait.
/// Crop its encoded side padding first, then cover the phone viewport.
class SplashVideoViewport extends StatelessWidget {
  const SplashVideoViewport(
      {super.key, required this.sourceSize, required this.child});
  final Size sourceSize;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (sourceSize.isEmpty) return const SizedBox.expand();
    final portraitWidth = sourceSize.width > sourceSize.height
        ? sourceSize.height * 9 / 16
        : sourceSize.width;
    return SizedBox.expand(
        child: ClipRect(
            child: FittedBox(
      fit: BoxFit.cover,
      alignment: Alignment.center,
      child: SizedBox(
          width: portraitWidth,
          height: sourceSize.height,
          child: ClipRect(
              child: OverflowBox(
            alignment: Alignment.center,
            minWidth: sourceSize.width,
            maxWidth: sourceSize.width,
            minHeight: sourceSize.height,
            maxHeight: sourceSize.height,
            child: SizedBox(
                width: sourceSize.width,
                height: sourceSize.height,
                child: child),
          ))),
    )));
  }
}
