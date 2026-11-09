import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../chat/domain/chat_models.dart';
import '../../chat/presentation/chat_providers.dart';

/// Photo chosen for a story, plus who will be allowed to view it.
class StoryDraft {
  const StoryDraft({required this.bytes, required this.visibility});

  final Uint8List bytes;
  final StoryVisibility visibility;
}

/// Full-screen photo. Privacy is chosen here, then the upload alert confirms it.
class StoryPreviewPage extends ConsumerStatefulWidget {
  const StoryPreviewPage({
    required this.image,
    required this.source,
    super.key,
  });

  final Uint8List image;
  final ImageSource source;

  @override
  ConsumerState<StoryPreviewPage> createState() => _StoryPreviewPageState();
}

class _StoryPreviewPageState extends ConsumerState<StoryPreviewPage> {
  StoryVisibility? _chosen;

  StoryVisibility _visibility(StoryVisibility? saved) {
    return _chosen ?? saved ?? StoryVisibility.public;
  }

  Future<void> _openSettings(StoryVisibility current) async {
    final picked = await showModalBottomSheet<StoryVisibility>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: RadioGroup<StoryVisibility>(
            groupValue: current,
            onChanged: (value) {
              if (value != null) Navigator.pop(context, value);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in StoryVisibility.values)
                  RadioListTile<StoryVisibility>(
                    value: option,
                    title: Text(option.label),
                    subtitle: Text(option.detail),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _chosen = picked);
  }

  Future<void> _confirm(StoryVisibility visibility) async {
    final upload = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final again = widget.source == ImageSource.camera
            ? 'Retake'
            : 'Choose again';
        return AlertDialog(
          title: const Text('Are you sure you want to upload?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                visibility.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(visibility.detail),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(again),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Upload'),
            ),
          ],
        );
      },
    );
    if (!mounted || upload == null) return;
    if (upload) {
      Navigator.of(context)
          .pop(StoryDraft(bytes: widget.image, visibility: visibility));
    } else {
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(storyPrivacyProvider).asData?.value;
    final visibility = _visibility(saved);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: Image.memory(widget.image, fit: BoxFit.contain)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const Spacer(),
                  Text(
                    visibility.label,
                    style: const TextStyle(color: Colors.white),
                  ),
                  IconButton(
                    tooltip: 'Who can view this story',
                    onPressed: () => _openSettings(visibility),
                    icon: const Icon(Icons.settings, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _confirm(visibility),
                    child: const Text('Upload'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
