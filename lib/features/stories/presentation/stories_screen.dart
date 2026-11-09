import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/opaque_content_surface.dart';
import '../../chat/domain/chat_models.dart';
import '../../chat/presentation/chat_providers.dart';
import '../../profile/data/profile_photo_codec.dart';
import '../../feed/presentation/feed_screen.dart';
import 'story_photo_flow.dart';
import 'story_viewer_page.dart';

class StoriesScreen extends ConsumerStatefulWidget {
  const StoriesScreen({super.key});

  @override
  ConsumerState<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends ConsumerState<StoriesScreen> {
  var _uploading = false;
  String? _error;

  Future<void> _addStory() async {
    final session = ref.read(sessionProvider);
    if (session == null) {
      setState(() => _error = 'Choose a name on the Chats tab first.');
      return;
    }
    setState(() => _error = null);
    try {
      final draft = await pickStoryPhoto(context);
      if (draft == null || !mounted) return;
      setState(() => _uploading = true);
      final jpeg = encodeProfileJpeg(draft.bytes, maxSide: 1280);
      await ref
          .read(chatRepositoryProvider)
          .uploadStory(
            session: session,
            bytes: jpeg,
            visibility: draft.visibility,
          );
      ref.invalidate(storiesProvider);
      ref.invalidate(storyPrivacyProvider);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _open(
    String name,
    List<StorySummary> stories,
    String baseUrl,
    String token, {
    required bool showViewers,
  }) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => StoryViewerPage(
          name: name,
          storyIds: [for (final story in stories) story.id],
          imageUrls: [
            for (final story in stories)
              storyImageUrl(baseUrl: baseUrl, storyId: story.id, token: token),
          ],
          recordView: true,
          showViewers: showViewers,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final session = ref.watch(sessionProvider);
    final stories = ref.watch(storiesProvider);
    final baseUrl = ref.watch(apiBaseProvider);
    final token = session?.token ?? '';

    return Material(
      type: MaterialType.transparency,
      child: stories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$error', textAlign: TextAlign.center),
          ),
        ),
        data: (items) {
          final mine = [
            for (final story in items)
              if (session != null && story.userId == session.userId) story,
          ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          final grouped = <String, List<StorySummary>>{};
          for (final story in items) {
            if (session != null && story.userId == session.userId) continue;
            grouped.putIfAbsent(story.userId, () => []).add(story);
          }
          for (final list in grouped.values) {
            list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          }
          final others = grouped.values.toList()
            ..sort((a, b) => b.last.createdAt.compareTo(a.last.createdAt));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              SizedBox(
                height: 116,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 1 + others.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _StoryRing(
                        label: 'Your story',
                        imageUrl: mine.isEmpty
                            ? null
                            : storyImageUrl(
                                baseUrl: baseUrl,
                                storyId: mine.last.id,
                                token: token,
                              ),
                        seen:
                            mine.isNotEmpty &&
                            mine.every((story) => story.seen),
                        showAdd: true,
                        busy: _uploading,
                        onTap: mine.isEmpty
                            ? _addStory
                            : () => _open(
                                session?.displayName ?? 'Your story',
                                mine,
                                baseUrl,
                                token,
                                showViewers: true,
                              ),
                        onAdd: _addStory,
                      );
                    }
                    final group = others[index - 1];
                    return _StoryRing(
                      label: group.first.displayName,
                      seen: group.every((story) => story.seen),
                      imageUrl: storyImageUrl(
                        baseUrl: baseUrl,
                        storyId: group.last.id,
                        token: token,
                      ),
                      onTap: () => _open(
                        group.first.displayName,
                        group,
                        baseUrl,
                        token,
                        showViewers: false,
                      ),
                    );
                  },
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: scheme.error)),
              ],
              const SizedBox(height: 12),
              OpaqueContentSurface(
                padding: const EdgeInsets.all(20),
                child: Text(
                  others.isEmpty && mine.isEmpty
                      ? 'No stories yet. Add a photo from your gallery or camera.'
                      : 'Stories stay up for 24 hours. Tap the left or right side of a photo to move between stories.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Feed', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              const FeedScreen(),
            ],
          );
        },
      ),
    );
  }
}

class _StoryRing extends StatelessWidget {
  const _StoryRing({
    required this.label,
    required this.onTap,
    this.imageUrl,
    this.seen = false,
    this.showAdd = false,
    this.busy = false,
    this.onAdd,
  });

  final String label;
  final String? imageUrl;
  final bool seen;
  final bool showAdd;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 76,
      child: Column(
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: busy ? null : onTap,
                  child: Container(
                    width: 72,
                    height: 72,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: imageUrl != null && !seen
                            ? scheme.primary
                            : scheme.outline,
                        width: 2.5,
                      ),
                    ),
                    child: ClipOval(
                      child: imageUrl == null
                          ? ColoredBox(
                              color: scheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.photo_camera_outlined,
                                color: scheme.onSurfaceVariant,
                              ),
                            )
                          : Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => ColoredBox(
                                color: scheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                if (showAdd)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: IconButton.filled(
                      tooltip: 'Add story',
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        minimumSize: const Size(28, 28),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: busy ? null : onAdd,
                      icon: busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add, size: 16),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(decoration: TextDecoration.none),
          ),
        ],
      ),
    );
  }
}
