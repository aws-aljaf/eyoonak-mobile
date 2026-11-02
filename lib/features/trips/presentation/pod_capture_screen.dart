import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';

import '../../../app/providers.dart';
import '../application/trips_providers.dart';

/// Module 22/section 15 — "POD (توقيع + صور + GPS + Timestamp)". GPS is
/// captured at the moment of submission and required (matches
/// UploadPodRequest's `lat`/`lng` being `required`, unlike the optional
/// GPS on a plain status change) — a POD with no location isn't
/// meaningful proof of anything.
class PodCaptureScreen extends ConsumerStatefulWidget {
  const PodCaptureScreen({super.key, required this.tripId, required this.stopId});

  final int tripId;
  final int stopId;

  @override
  ConsumerState<PodCaptureScreen> createState() => _PodCaptureScreenState();
}

class _PodCaptureScreenState extends ConsumerState<PodCaptureScreen> {
  final _signatureController = SignatureController(penStrokeWidth: 3, penColor: Colors.black);
  final _receiverNameController = TextEditingController();
  final _receiverPhoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _picker = ImagePicker();

  final List<XFile> _photos = [];
  bool _submitting = false;

  @override
  void dispose() {
    _signatureController.dispose();
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('توثيق التسليم (POD)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _receiverNameController,
            decoration: const InputDecoration(labelText: 'اسم المستلم *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _receiverPhoneController,
            decoration: const InputDecoration(labelText: 'هاتف المستلم', border: OutlineInputBorder()),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder()),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Text('التوقيع', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
            height: 180,
            child: Signature(controller: _signatureController, backgroundColor: Colors.white),
          ),
          TextButton(onPressed: _signatureController.clear, child: const Text('مسح التوقيع')),
          const SizedBox(height: 16),
          Text('الصور', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._photos.map(
                (photo) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(photo.path), width: 72, height: 72, fit: BoxFit.cover),
                ),
              ),
              IconButton.filledTonal(
                onPressed: _addPhoto,
                icon: const Icon(Icons.add_a_photo_outlined),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('حفظ وإرسال'),
          ),
        ],
      ),
    );
  }

  Future<void> _addPhoto() async {
    final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);

    if (photo != null) {
      setState(() => _photos.add(photo));
    }
  }

  Future<void> _submit() async {
    if (_receiverNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اسم المستلم مطلوب')));

      return;
    }

    setState(() => _submitting = true);

    try {
      final position = await Geolocator.getCurrentPosition();
      String? signaturePath;

      if (_signatureController.isNotEmpty) {
        final bytes = await _signatureController.toPngBytes();

        if (bytes != null) {
          signaturePath = await _saveBytesToQueueFile(bytes, 'signature_${widget.stopId}.png');
        }
      }

      await ref.read(tripsRepositoryProvider).uploadPod(
            widget.tripId,
            widget.stopId,
            receiverName: _receiverNameController.text.trim(),
            receiverPhone: _receiverPhoneController.text.trim().isEmpty ? null : _receiverPhoneController.text.trim(),
            lat: position.latitude,
            lng: position.longitude,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            signaturePath: signaturePath,
            photoPaths: _photos.map((photo) => photo.path).toList(),
          );

      ref.invalidate(tripDetailProvider(widget.tripId));
      ref.invalidate(myTripsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ توثيق التسليم')));
        context.pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديد الموقع: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<String> _saveBytesToQueueFile(Uint8List bytes, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'pod_queue', fileName));
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);

    return file.path;
  }
}
