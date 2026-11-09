import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/opaque_content_surface.dart';
import '../../../core/widgets/readable_text_field.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../chat/presentation/chat_providers.dart';
import 'profile_photo_controller.dart';
import 'profile_photo_flow.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).signIn(_name.text);
      _name.clear();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePhoto() async {
    if (ref.read(sessionProvider) == null) {
      setState(() => _error = 'Save a name first, then add a photo.');
      return;
    }
    setState(() => _error = null);
    try {
      final bytes = await pickProfilePhoto(context);
      if (bytes == null || !mounted) return;
      await ref.read(profilePhotoProvider.notifier).save(bytes);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final session = ref.watch(sessionProvider);
    final name = session?.displayName ?? 'You';
    final photo = ref.watch(profilePhotoProvider).asData?.value;

    return Material(
      type: MaterialType.transparency,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          OpaqueContentSurface(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: 'Change profile photo',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _busy ? null : _changePhoto,
                    child: Stack(
                      children: [
                        UserAvatar(name: name, radius: 36, imageBytes: photo),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                            child: const Icon(Icons.photo_camera, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        session == null
                            ? 'Add a name so other people can find you.'
                            : 'Tap your photo to change it. Other people see this name in chats.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ReadableTextField(
            controller: _name,
            hint: session == null ? 'Your name' : 'Change name',
            onSubmitted: (_) => _saveName(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _busy ? null : _saveName,
              child: Text(_busy ? 'Saving…' : 'Save name'),
            ),
          ),
          const SizedBox(height: 8),
          OpaqueContentSurface(
            child: ListTile(
              leading: const Icon(CupertinoIcons.settings),
              title: const Text('Settings'),
              subtitle: const Text('Theme and chat server'),
              trailing: const Icon(CupertinoIcons.chevron_right),
              onTap: () => context.push('/settings'),
            ),
          ),
        ],
      ),
    );
  }
}
