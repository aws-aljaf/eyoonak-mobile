import '../../../core/widgets/family_motion.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_exception.dart';
import '../application/family_providers.dart';
import '../data/family_models.dart';

/// Generates a fresh device-pairing code for one family member — the
/// mobile mirror of `FamilyTrackingPage.vue`'s `openPairing()` dialog,
/// minus the QR image (see the class-level reasoning below). The *other*
/// half of this flow, redeeming a code on the device being paired, is
/// `DevicePairingRedeemScreen`; this screen is opened from a member's card
/// on `FamilyHomeScreen` by whoever is setting that member's device up.
///
/// Deliberately no QR code here, even though the web app shows one: the
/// web page's QR encodes a deep link (`origin/devices/pair?code=...`) that
/// opens a *browser* pairing page, and this app has no camera-based QR
/// *scanner* on the redeem side either (`DevicePairingRedeemScreen` is
/// text-entry only, by the same reasoning documented there) — so a QR
/// image here would have nothing of this app's own to be scanned by, and
/// adding a QR-generation dependency to produce an image nobody in this
/// app can consume yet isn't worth it. The large, copyable code text below
/// is the same fallback the web page already offers for manual entry, and
/// covers the actual case: typing the code into this same app's redeem
/// screen on the other device.
class DevicePairingGenerateScreen extends ConsumerStatefulWidget {
  const DevicePairingGenerateScreen({super.key, required this.familyMemberId, required this.memberName});

  final int familyMemberId;
  final String memberName;

  @override
  ConsumerState<DevicePairingGenerateScreen> createState() => _DevicePairingGenerateScreenState();
}

class _DevicePairingGenerateScreenState extends ConsumerState<DevicePairingGenerateScreen> {
  bool _loading = true;
  String? _errorMessage;
  DevicePairingCode? _pairing;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final familyId = ref.read(selectedFamilyIdProvider);
      final raw = await ref.read(familyApiProvider).generatePairingCode(
            familyMemberId: widget.familyMemberId,
            familyId: familyId,
          );

      if (!mounted) return;
      setState(() => _pairing = DevicePairingCode.fromJson(raw));

      // Ticks the countdown text once a second. A plain rebuild trigger —
      // the actual remaining time is always recomputed from `expiresAt` in
      // build() below, never accumulated here, so a missed frame (e.g. the
      // app backgrounded) can never leave a stale countdown on resume.
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الكود')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ربط جهاز لـ ${widget.memberName}')),
      body: Center(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const CircularProgressIndicator();
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('تعذر إنشاء كود الإقران: $_errorMessage', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _generate, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }

    final pairing = _pairing;
    if (pairing == null) {
      // Unreachable in practice (either _loading or _errorMessage covers
      // every other path out of _generate()) — kept only so this method
      // has a total, non-nullable return without a `!`.
      return const SizedBox.shrink();
    }

    final remaining = pairing.expiresAt.difference(DateTime.now());
    final expired = remaining.isNegative;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FamilyHero(playful: false, title: 'وصلة أمان لأهل البيت', subtitle: 'هذا الكود يربط الجهاز بالفرد المحدد. شاركه فقط مع صاحب الجهاز.'),
          const Text('أعطِ هذا الكود للجهاز الذي تريد ربطه بهذا الفرد،', textAlign: TextAlign.center),
          const Text('وأدخِله في شاشة "ربط جهاز" هناك خلال المدة أدناه.', textAlign: TextAlign.center),
          const SizedBox(height: 24),
          SelectableText(
            pairing.code,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 6,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            expired ? 'انتهت صلاحية هذا الكود.' : 'صالح لمدة ${_formatCountdown(remaining)} دقيقة.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: expired || remaining.inMinutes < 2 ? Colors.red.shade700 : null,
                ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: expired ? null : () => _copyCode(pairing.code),
                icon: const Icon(Icons.copy),
                label: const Text('نسخ الكود'),
              ),
              ElevatedButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.refresh),
                label: const Text('إنشاء كود جديد'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "m:ss", floored at "0:00" rather than going negative — `expired` above
/// is what actually gates the "انتهت الصلاحية" message, so this only ever
/// renders non-negative durations in practice, but the clamp keeps it
/// honest if called on the boundary tick.
String _formatCountdown(Duration remaining) {
  final clamped = remaining.isNegative ? Duration.zero : remaining;
  final minutes = clamped.inMinutes;
  final seconds = clamped.inSeconds % 60;

  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
