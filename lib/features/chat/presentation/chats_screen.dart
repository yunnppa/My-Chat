import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/opaque_content_surface.dart';
import '../../../core/widgets/readable_text_field.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../stories/presentation/story_viewer_page.dart';
import '../domain/chat_models.dart';
import 'chat_providers.dart';

class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    if (session == null) {
      return const Material(
        type: MaterialType.transparency,
        child: _SignInPrompt(),
      );
    }

    final chats = ref.watch(chatsProvider);
    final baseUrl = ref.watch(apiBaseProvider);
    return Material(
      type: MaterialType.transparency,
      child: chats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _MessageState(
          message: '$error',
          action: 'Retry',
          onPressed: () => ref.invalidate(chatsProvider),
        ),
        data: (items) {
          return RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                ref.refresh(chatsProvider.future),
                ref.refresh(storiesProvider.future),
              ]);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => context.push('/new-chat'),
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text('New chat'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () => context.push('/friends'),
                            icon: const Icon(Icons.group_add_outlined),
                            label: const Text('Add friend'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (items.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'Search for someone who is signed in and add a chat.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _ChatRow(chat: items[index], baseUrl: baseUrl),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ChatRow extends ConsumerWidget {
  const _ChatRow({required this.chat, required this.baseUrl});

  final ChatSummary chat;
  final String baseUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final unread = visibleUnread(ref.watch(unreadDismissalProvider), chat);
    final session = ref.watch(sessionProvider);
    final userStories = [
      for (final story
          in ref.watch(storiesProvider).asData?.value ?? const <StorySummary>[])
        if (story.userId == chat.otherUserId) story,
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final unseen = userStories.any((story) => !story.seen);
    final avatar = UserAvatar(
      name: chat.title,
      radius: 24,
      imageUrl: profileAvatarUrl(
        baseUrl: baseUrl,
        userId: chat.otherUserId,
        revision: chat.avatarRevision,
      ),
    );
    return OpaqueContentSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: userStories.isEmpty
            ? avatar
            : GestureDetector(
                onTap: () {
                  if (session == null) return;
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => StoryViewerPage(
                        name: chat.title,
                        storyIds: [for (final story in userStories) story.id],
                        imageUrls: [
                          for (final story in userStories)
                            storyImageUrl(
                              baseUrl: baseUrl,
                              storyId: story.id,
                              token: session.token,
                            ),
                        ],
                        recordView: session.userId != chat.otherUserId,
                        showViewers: false,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: unseen ? scheme.primary : scheme.outline,
                      width: 2.5,
                    ),
                  ),
                  child: avatar,
                ),
              ),
        title: Text(
          chat.title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: unread > 0 ? FontWeight.w700 : null),
        ),
        subtitle: Text(
          chat.preview.isEmpty ? 'No messages yet' : chat.preview,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            decoration: TextDecoration.none,
            fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        trailing: unread > 0
            ? Badge(
                label: Text(unread > 99 ? '99+' : '$unread'),
                backgroundColor: scheme.primary,
              )
            : null,
        onTap: () => context.push(
          '/chat/${chat.id}?title=${Uri.encodeComponent(chat.title)}',
        ),
      ),
    );
  }
}

class _SignInPrompt extends ConsumerStatefulWidget {
  const _SignInPrompt();

  @override
  ConsumerState<_SignInPrompt> createState() => _SignInPromptState();
}

class _SignInPromptState extends ConsumerState<_SignInPrompt> {
  final _name = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).signIn(_name.text);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        Text(
          'Choose a name so other people can message you.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        ReadableTextField(
          controller: _name,
          hint: 'Your name',
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: scheme.error)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Connecting…' : 'Continue'),
        ),
      ],
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.message,
    required this.action,
    required this.onPressed,
  });

  final String message;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onPressed, child: Text(action)),
          ],
        ),
      ),
    );
  }
}
