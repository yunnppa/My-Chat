import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/readable_glass.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/readable_text_field.dart';
import '../../../core/widgets/user_avatar.dart';
import '../domain/chat_models.dart';
import 'chat_providers.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({
    required this.chatId,
    required this.title,
    super.key,
  });

  final String chatId;
  final String title;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _composer = TextEditingController();
  var _sending = false;

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final session = ref.watch(sessionProvider);
    final messages = ref.watch(conversationProvider(widget.chatId));
    final baseUrl = ref.watch(apiBaseProvider);
    final chat = ref
        .watch(chatsProvider)
        .asData
        ?.value
        .where((item) => item.id == widget.chatId)
        .firstOrNull;

    return GlassScaffold(
      background: const AppBackground(),
      extendBody: false,
      statusBarStyle: GlassStatusBarStyle.auto,
      resizeToAvoidBottomInset: true,
      appBar: GlassAppBar(
        leading: GlassIconButton(
          semanticLabel: 'Back',
          icon: Icon(CupertinoIcons.back, color: scheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
        actions: [
          GlassMenu(
            menuAlignment: GlassMenuAlignment.topRight,
            menuWidth: 200,
            settings: readableGlassSettings,
            triggerBuilder: (context, toggle) => GlassIconButton(
              semanticLabel: 'Chat options',
              icon: Icon(CupertinoIcons.ellipsis, color: scheme.onSurface),
              onPressed: toggle,
            ),
            items: [
              GlassMenuItem(
                title: 'Delete',
                isDestructive: true,
                icon: const Icon(CupertinoIcons.trash),
                titleStyle: TextStyle(
                  color: scheme.error,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                  decorationColor: Colors.transparent,
                ),
                onTap: _confirmDelete,
              ),
            ],
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: UserAvatar(
                name: widget.title,
                radius: 14,
                imageUrl: chat == null
                    ? null
                    : profileAvatarUrl(
                        baseUrl: baseUrl,
                        userId: chat.otherUserId,
                        revision: chat.avatarRevision,
                      ),
              ),
            ),
          ),
        ],
      ),
      body: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            Expanded(
              child: messages.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$error', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => ref.invalidate(
                            conversationProvider(widget.chatId),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const Center(child: Text('Say hello.'));
                  }
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final message = items[items.length - 1 - index];
                      return _Bubble(
                        message: message,
                        outgoing: message.senderId == session?.userId,
                        outgoingColor: colors.messageOutgoing,
                        incomingColor: colors.messageIncoming,
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: ReadableTextField(
                        controller: _composer,
                        hint: 'Message',
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GlassIconButton(
                      semanticLabel: 'Send message',
                      icon: Icon(
                        CupertinoIcons.arrow_up,
                        color: scheme.onSurface,
                      ),
                      onPressed: _sending ? null : _send,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(conversationProvider(widget.chatId).notifier).send(text);
      _composer.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmDelete() async {
    final scope = await showDialog<ChatDeleteScope>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('Delete conversation?'),
          content: const Text(
            'Delete for you removes the chat from your list only. '
            'Delete for both removes it and all messages for you and the other person.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ChatDeleteScope.forMe),
              child: const Text('Delete for you'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: scheme.error),
              onPressed: () => Navigator.pop(context, ChatDeleteScope.forBoth),
              child: const Text('Delete for both'),
            ),
          ],
        );
      },
    );
    if (scope == null || !mounted) return;
    try {
      await ref
          .read(conversationProvider(widget.chatId).notifier)
          .deleteConversation(scope);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.outgoing,
    required this.outgoingColor,
    required this.incomingColor,
  });

  final ChatMessage message;
  final bool outgoing;
  final Color outgoingColor;
  final Color incomingColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: outgoing ? outgoingColor : incomingColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          message.text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: outgoing ? Colors.white : scheme.onSurface,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
