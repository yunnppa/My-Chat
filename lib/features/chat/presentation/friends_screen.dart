import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/readable_text_field.dart';
import '../../../core/widgets/user_avatar.dart';
import 'chat_providers.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _username = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final session = ref.read(sessionProvider);
    if (session == null) {
      setState(() => _error = 'Choose a name on the Chats tab first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(chatRepositoryProvider)
          .addFriend(session: session, username: _username.text);
      _username.clear();
      ref.invalidate(friendsProvider);
      ref.invalidate(storiesProvider);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final friends = ref.watch(friendsProvider);
    final baseUrl = ref.watch(apiBaseProvider);

    return GlassScaffold(
      background: const AppBackground(),
      extendBody: false,
      statusBarStyle: GlassStatusBarStyle.auto,
      appBar: GlassAppBar(
        leading: GlassIconButton(
          semanticLabel: 'Back',
          icon: Icon(CupertinoIcons.back, color: scheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Add friend',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
      ),
      body: Material(
        type: MaterialType.transparency,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'Enter the exact username. Friends can see stories you set to Friends only.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 12),
            ReadableTextField(
              controller: _username,
              hint: 'Username',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _add(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _busy ? null : _add,
                child: Text(_busy ? 'Adding…' : 'Add friend'),
              ),
            ),
            const SizedBox(height: 16),
            friends.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('$error'),
              data: (people) {
                if (people.isEmpty) {
                  return const Text('You have not added any friends yet.');
                }
                return Column(
                  children: [
                    for (final person in people) ...[
                      ListTile(
                        tileColor: scheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        leading: UserAvatar(
                          name: person.displayName,
                          imageUrl: profileAvatarUrl(
                            baseUrl: baseUrl,
                            userId: person.id,
                            revision: person.avatarRevision,
                          ),
                        ),
                        title: Text(person.displayName),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
