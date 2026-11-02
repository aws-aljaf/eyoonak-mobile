import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../app/providers.dart';
import '../../trips/application/trips_providers.dart';

/// Module 29 — "SOS مع تأكيد". The confirmation dialog IS the
/// confirmation step the backend's docblock refers to (SosController)
/// — by the time SosRepository.trigger() is called, the driver has
/// explicitly confirmed once.
class SosButton extends ConsumerWidget {
  const SosButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.extended(
      backgroundColor: Colors.red.shade700,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.sos),
      label: const Text('SOS'),
      onPressed: () => _handleTap(context, ref),
    );
  }

  Future<void> _handleTap(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نداء استغاثة (SOS)'),
        content: const Text(
          'سيتم إرسال موقعك الحالي فورًا إلى كل المسؤولين في شركتك. هل أنت متأكد؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نعم، أرسل الآن'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      final activeTrip = await ref.read(activeTripProvider.future);

      await ref.read(sosRepositoryProvider).trigger(
            lat: position.latitude,
            lng: position.longitude,
            tripId: activeTrip?.id,
          );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال نداء الاستغاثة. سيتم التواصل معك قريبًا.')),
        );
      }
    } catch (error) {
      // The action is already queued locally by SosRepository even if
      // this specific attempt to read GPS/flush fails outright — but
      // getCurrentPosition() itself can throw before anything is queued
      // (permission denied). Surface that clearly rather than silently
      // doing nothing on the single most safety-critical button in the
      // app.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديد الموقع لإرسال SOS: $error')),
        );
      }
    }
  }
}
