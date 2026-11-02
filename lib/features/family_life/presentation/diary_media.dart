import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../../app/providers.dart';

class PrivateDiaryImage extends ConsumerStatefulWidget {
  const PrivateDiaryImage({super.key, required this.url});
  final String url;
  @override
  ConsumerState<PrivateDiaryImage> createState() => _PrivateDiaryImageState();
}

class _PrivateDiaryImageState extends ConsumerState<PrivateDiaryImage> {
  late final future = ref.read(apiClientProvider).downloadBytes(widget.url);
  @override
  Widget build(BuildContext context) => FutureBuilder<List<int>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text('تعذر تحميل الصورة الخاصة.');
        if (!snapshot.hasData) return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
        return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(Uint8List.fromList(snapshot.data!), height: 180, fit: BoxFit.contain));
      });
}

class PrivateDiaryAudio extends ConsumerStatefulWidget {
  const PrivateDiaryAudio({super.key, required this.url});
  final String url;
  @override
  ConsumerState<PrivateDiaryAudio> createState() => _PrivateDiaryAudioState();
}

class _PrivateDiaryAudioState extends ConsumerState<PrivateDiaryAudio> {
  final player = AudioPlayer(useProxyForRequestHeaders: false);
  bool loaded = false, busy = false;
  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  Future<void> toggle() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (!loaded) {
        final token = await ref.read(secureTokenStoreProvider).readToken();
        await player.setUrl(widget.url, headers: token == null ? null : {'Authorization': 'Bearer $token'});
        loaded = true;
      }
      if (player.playing) {
        await player.pause();
      } else {
        if (player.processingState == ProcessingState.completed) await player.seek(Duration.zero);
        unawaited(player.play());
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تشغيل التسجيل الخاص.')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, snapshot) => ListTile(
          leading: const Icon(Icons.mic_rounded),
          title: const Text('ذكرى بصوتك'),
          trailing: IconButton(
              onPressed: busy ? null : toggle,
              tooltip: player.playing ? 'إيقاف مؤقت' : 'تشغيل التسجيل',
              icon: Icon(player.playing ? Icons.pause_circle : Icons.play_circle))));
}

class DiaryRecorderDialog extends StatefulWidget {
  const DiaryRecorderDialog({super.key});
  @override
  State<DiaryRecorderDialog> createState() => _DiaryRecorderDialogState();
}

class _DiaryRecorderDialogState extends State<DiaryRecorderDialog> {
  final recorder = AudioRecorder();
  Timer? timer;
  bool recording = false, busy = false, finished = false;
  String? path, error;
  int seconds = 0;
  @override
  void dispose() {
    timer?.cancel();
    if (!finished) recorder.cancel();
    recorder.dispose();
    super.dispose();
  }

  Future<void> start() async {
    setState(() => busy = true);
    try {
      if (!await recorder.hasPermission()) {
        if (mounted) setState(() => error = 'اسمح بالمايكروفون حتى تسجل ذكراك.');
        return;
      }
      final folder = await getTemporaryDirectory();
      path = '${folder.path}/eyoonak-diary-${DateTime.now().microsecondsSinceEpoch}.m4a';
      await recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 22050),
          path: path!);
      if (mounted) setState(() => recording = true);
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => seconds++);
        if (seconds >= 120) stop();
      });
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر بدء التسجيل.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> stop() async {
    if (busy || !recording) return;
    setState(() => busy = true);
    timer?.cancel();
    try {
      final result = await recorder.stop();
      finished = true;
      if (mounted) Navigator.pop(context, result);
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر حفظ التسجيل.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !busy,
      child: AlertDialog(
          title: const Text('ذكرى بصوتك 🎙️'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(recording ? Icons.mic : Icons.mic_none, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(recording
                ? '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}'
                : 'التسجيل يبقى خاصاً مع مذكرتك'),
            const Text('حتى دقيقتين'),
            if (error != null) Text(error!)
          ]),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(
                onPressed: busy
                    ? null
                    : recording
                        ? stop
                        : start,
                child: Text(recording ? 'حفظ التسجيل' : 'ابدأ التسجيل'))
          ]));
}
