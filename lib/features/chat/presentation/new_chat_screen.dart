import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/readable_text_field.dart';
import '../../../core/widgets/user_avatar.dart';
import 'chat_providers.dart';

class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  var _loading = true;
  var _openingId = '';
  Object? _error;
  List<({String id, String name, int avatarRevision})> _people = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _load);
  }

  Future<void> _load() async {
    final session = ref.read(sessionProvider);
    if (session == null) {
      setState(() {
        _loading = false;
        _error = 'Set your name on the Chats tab first.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final people = await ref
          .read(chatRepositoryProvider)
          .searchPeople(session, _query.text);
      if (!mounted) return;
      people.sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
      setState(() {
        _people = [
          for (final person in people)
            (
              id: person.id,
              name: person.displayName,
              avatarRevision: person.avatarRevision,
            ),
        ];
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _open(String userId, String name) async {
    final session = ref.read(sessionProvider);
    if (session == null || _openingId.isNotEmpty) return;
    setState(() => _openingId = userId);
    try {
      final chat = await ref
          .read(chatRepositoryProvider)
          .openDirectChat(session: session, otherUserId: userId);
      ref.invalidate(chatsProvider);
      if (!mounted) return;
      context.push('/chat/${chat.id}?title=${Uri.encodeComponent(name)}');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _openingId = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final existing = ref.watch(chatsProvider).value ?? const [];
    final existingIds = {for (final chat in existing) chat.otherUserId};
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
          'New chat',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
      ),
      body: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: ReadableTextField(
                controller: _query,
                hint: 'Search people by name',
                textInputAction: TextInputAction.search,
                onChanged: _onQueryChanged,
                onSubmitted: (_) => _load(),
              ),
            ),
            Expanded(child: _body(scheme, existingIds, baseUrl)),
          ],
        ),
      ),
    );
  }

  Widget _body(ColorScheme scheme, Set<String> existingIds, String baseUrl) {
    if (_loading && _people.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _people.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$_error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_people.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No one else matches that name. Each person must open the app and choose a name.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _people.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final person = _people[index];
        final alreadyAdded = existingIds.contains(person.id);
        return ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          tileColor: scheme.surface,
          leading: UserAvatar(
            name: person.name,
            imageUrl: profileAvatarUrl(
              baseUrl: baseUrl,
              userId: person.id,
              revision: person.avatarRevision,
            ),
          ),
          title: Text(person.name),
          subtitle: Text(alreadyAdded ? 'Already in your chats' : 'Start chat'),
          trailing: _openingId == person.id
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  alreadyAdded
                      ? CupertinoIcons.chat_bubble
                      : CupertinoIcons.add,
                ),
          onTap: () => _open(person.id, person.name),
        );
      },
    );
  }
}
