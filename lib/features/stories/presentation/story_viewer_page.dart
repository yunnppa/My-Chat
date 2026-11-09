import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/user_avatar.dart';
import '../../chat/domain/chat_models.dart';
import '../../chat/presentation/chat_providers.dart';

/// Full-screen story photos. The picture stays opaque.
class StoryViewerPage extends ConsumerStatefulWidget {
  const StoryViewerPage({
    required this.name,
    required this.storyIds,
    required this.imageUrls,
    required this.recordView,
    required this.showViewers,
    super.key,
  });

  final String name;
  final List<String> storyIds;
  final List<String> imageUrls;

  /// True when this person is not the author, so opening the story counts.
  final bool recordView;

  /// The viewer list is shown only to the person who posted the story.
  final bool showViewers;

  @override
  ConsumerState<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends ConsumerState<StoryViewerPage> {
  var _index = 0;
  List<ChatPerson> _viewers = const [];
  var _loadingViewers = true;
  String? _viewersError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync(0));
  }

  void _show(int index) {
    if (index < 0 || index == _index) return;
    if (index >= widget.imageUrls.length) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _index = index);
    _sync(index);
  }

  Future<void> _sync(int index) async {
    final session = ref.read(sessionProvider);
    if (session == null || index < 0 || index >= widget.storyIds.length) {
      return;
    }
    final storyId = widget.storyIds[index];
    final repository = ref.read(chatRepositoryProvider);
    if (widget.recordView) {
      try {
        await repository.markStoryViewed(session: session, storyId: storyId);
      } catch (_) {}
    }
    if (!widget.showViewers) {
      if (mounted && _index == index) {
        setState(() => _loadingViewers = false);
      }
      return;
    }
    if (!mounted || _index != index) return;
    setState(() {
      _loadingViewers = true;
      _viewersError = null;
    });
    try {
      final people = await repository.storyViewers(
        session: session,
        storyId: storyId,
      );
      if (!mounted || _index != index) return;
      setState(() {
        _viewers = people;
        _loadingViewers = false;
      });
    } catch (error) {
      if (!mounted || _index != index) return;
      setState(() {
        _viewersError = '$error';
        _loadingViewers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseUrl = ref.watch(apiBaseProvider);
    ref.listen(storiesProvider, (_, _) {
      if (widget.showViewers && widget.storyIds.isNotEmpty) _sync(_index);
    });

    final count = widget.imageUrls.length;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: widget.showViewers ? 210 : 0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final width = constraints.maxWidth;
                    if (details.localPosition.dx < width / 2) {
                      _show(_index - 1);
                    } else {
                      _show(_index + 1);
                    }
                  },
                  child: Center(
                    child: Image.network(
                      widget.imageUrls[_index],
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Text(
                        'Could not load this story.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < count; i++)
                        Expanded(
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: i <= _index
                                  ? Colors.white
                                  : Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          widget.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                decoration: TextDecoration.none,
                              ),
                        ),
                      ),
                      Text(
                        '${_index + 1}/$count',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (widget.showViewers)
            Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                color: const Color(0xF0111111),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: _ViewersPanel(
                      loading: _loadingViewers,
                      error: _viewersError,
                      viewers: _viewers,
                      baseUrl: baseUrl,
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

class _ViewersPanel extends StatelessWidget {
  const _ViewersPanel({
    required this.loading,
    required this.error,
    required this.viewers,
    required this.baseUrl,
  });

  final bool loading;
  final String? error;
  final List<ChatPerson> viewers;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Viewed by',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        Expanded(child: _body(context)),
      ],
    );
  }

  Widget _body(BuildContext context) {
    if (loading && viewers.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (error != null && viewers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(error!, style: const TextStyle(color: Colors.white70)),
      );
    }
    if (viewers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'No one has viewed this story yet.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    return ListView.builder(
      itemCount: viewers.length,
      itemBuilder: (context, index) {
        final person = viewers[index];
        return ListTile(
          dense: true,
          leading: UserAvatar(
            name: person.displayName,
            radius: 16,
            imageUrl: profileAvatarUrl(
              baseUrl: baseUrl,
              userId: person.id,
              revision: person.avatarRevision,
            ),
          ),
          title: Text(
            person.displayName,
            style: const TextStyle(
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
        );
      },
    );
  }
}

String storyImageUrl({
  required String baseUrl,
  required String storyId,
  required String token,
}) {
  final base = Uri.parse(baseUrl);
  return base
      .replace(
        path: '/v1/stories/$storyId/image',
        queryParameters: {'token': token},
      )
      .toString();
}
