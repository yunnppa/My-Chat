import 'package:flutter/material.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../core/widgets/opaque_content_surface.dart';

/// Feed with opaque post cards and glass filter chips in chrome only.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  int _filterIndex = 0;

  static const _filters = ['All', 'Friends', 'Nearby'];
  static const _posts = [
    (
      author: 'Alex Rivera',
      body: 'Sunset walk by the river. Who else is out tonight?',
      meta: '2h · Public',
    ),
    (
      author: 'Design Team',
      body: 'Shipped the new chat composer. Feedback welcome.',
      meta: '5h · Friends',
    ),
    (
      author: 'Sam Chen',
      body: 'Live location sharing is ready for testing on mid-range Android.',
      meta: '1d · Public',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (var i = 0; i < _filters.length; i++)
              GlassChip(
                label: _filters[i],
                selected: _filterIndex == i,
                onTap: () => setState(() => _filterIndex = i),
              ),
          ],
        ),
        const SizedBox(height: 16),
        for (final post in _posts) ...[
          OpaqueContentSurface(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.author,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  post.meta,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                Text(post.body, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
