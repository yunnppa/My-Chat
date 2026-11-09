import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/widgets/photo_source_sheet.dart';
import '../data/profile_photo_codec.dart';

/// Circle crop for a profile photo, with a way to pick or shoot again.
class ProfilePhotoCropPage extends StatefulWidget {
  const ProfilePhotoCropPage({
    required this.image,
    required this.source,
    super.key,
  });

  final Uint8List image;
  final ImageSource source;

  @override
  State<ProfilePhotoCropPage> createState() => _ProfilePhotoCropPageState();
}

class _ProfilePhotoCropPageState extends State<ProfilePhotoCropPage> {
  final _controller = CropController();
  final _picker = ImagePicker();
  var _imageReady = false;
  var _cropping = false;
  var _retaking = false;
  String? _error;

  Future<void> _retake() async {
    setState(() {
      _retaking = true;
      _error = null;
    });
    try {
      final picked = await _picker.pickImage(
        source: widget.source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.front,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      _controller.image = bytes;
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = photoPickerError(error));
    } finally {
      if (mounted) setState(() => _retaking = false);
    }
  }

  void _usePhoto() {
    setState(() {
      _cropping = true;
      _error = null;
    });
    _controller.crop();
  }

  void _onCropped(CropResult result) {
    if (!mounted) return;
    switch (result) {
      case CropSuccess(:final croppedImage):
        try {
          final jpeg = encodeProfileJpeg(croppedImage);
          Navigator.of(context).pop(jpeg);
        } catch (error) {
          setState(() {
            _cropping = false;
            _error = '$error'.replaceFirst('FormatException: ', '');
          });
        }
      case CropFailure():
        setState(() {
          _cropping = false;
          _error = 'Could not crop that photo. Move it and try again.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = _cropping || _retaking;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Crop photo'),
        leading: IconButton(
          tooltip: 'Cancel',
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Crop(
              image: widget.image,
              controller: _controller,
              onCropped: _onCropped,
              aspectRatio: 1,
              withCircleUi: true,
              interactive: true,
              fixCropRect: true,
              baseColor: Colors.black,
              maskColor: Colors.black54,
              initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
                size: 0.9,
                aspectRatio: 1,
              ),
              onStatusChanged: (status) {
                final ready = status == CropStatus.ready;
                if (ready == _imageReady) return;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _imageReady = ready);
                });
              },
              progressIndicator: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
          Material(
            color: Colors.black,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Move and pinch the photo. Retake it if you want a different one.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: TextStyle(color: scheme.error)),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: busy || !_imageReady ? null : _retake,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                            ),
                            child: Text(_retaking ? 'Opening…' : 'Retake'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: busy || !_imageReady ? null : _usePhoto,
                            child: Text(_cropping ? 'Saving…' : 'Use photo'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
