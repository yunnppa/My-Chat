import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/readable_glass.dart';
import '../../../core/widgets/app_background.dart';
import '../../chat/presentation/chat_providers.dart';

/// Primary navigation shell with Liquid Glass chrome.
///
/// Glass is limited to the scaffold, app bar actions, tab bar, menus and
/// sheets. Branch content stays opaque for readability.
class HomeShell extends ConsumerWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _titles = ['Chats', 'Stories', 'Profile'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = navigationShell.currentIndex;
    final scheme = Theme.of(context).colorScheme;
    final dismissal = ref.watch(unreadDismissalProvider);
    final unread = ref
        .watch(chatsProvider)
        .maybeWhen(
          data: (chats) => chats.fold<int>(
            0,
            (total, chat) => total + visibleUnread(dismissal, chat),
          ),
          orElse: () => 0,
        );

    return GlassScaffold(
      background: const AppBackground(),
      // Keep list content below the status bar and app bar. The default
      // full-bleed body paints the first row through the top chrome.
      extendBody: false,
      statusBarStyle: Theme.of(context).brightness == Brightness.dark
          ? GlassStatusBarStyle.light
          : GlassStatusBarStyle.dark,
      appBar: GlassAppBar(
        title: Text(
          _titles[index],
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (index == 0)
            GlassIconButton(
              semanticLabel: 'Find people',
              icon: Icon(CupertinoIcons.search, color: scheme.onSurface),
              onPressed: () => context.push('/new-chat'),
            ),
          GlassMenu(
            menuAlignment: GlassMenuAlignment.topRight,
            menuWidth: 220,
            triggerBuilder: (context, toggle) => GlassIconButton(
              semanticLabel: 'Open menu',
              icon: Icon(CupertinoIcons.ellipsis, color: scheme.onSurface),
              onPressed: toggle,
            ),
            items: [
              GlassMenuItem(
                title: 'New chat',
                icon: const Icon(CupertinoIcons.bubble_left),
                onTap: () => context.push('/new-chat'),
              ),
              GlassMenuItem(
                title: 'Settings',
                icon: const Icon(CupertinoIcons.settings),
                onTap: () => context.push('/settings'),
              ),
              const GlassMenuDivider(),
              GlassMenuItem(
                title: 'About ChatApp',
                icon: const Icon(CupertinoIcons.info),
                onTap: () => _showAboutDialog(context),
              ),
            ],
          ),
        ],
      ),
      bottomBar: GlassTabBar.bottom(
        selectedIndex: index,
        settings: readableGlassSettings,
        indicatorSettings: readableGlassSettings,
        glowOpacity: 0,
        selectedLabelStyle: readableLabelStyle.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        unselectedLabelStyle: readableLabelStyle.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.72),
        ),
        onTabSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        tabs: [
          GlassTab(
            icon: _UnreadIcon(count: unread, filled: false),
            activeIcon: _UnreadIcon(count: unread, filled: true),
            label: 'Chats',
          ),
          const GlassTab(
            icon: Icon(CupertinoIcons.circle),
            activeIcon: Icon(CupertinoIcons.circle_fill),
            label: 'Stories',
          ),
          const GlassTab(
            icon: Icon(CupertinoIcons.person),
            activeIcon: Icon(CupertinoIcons.person_fill),
            label: 'Profile',
          ),
        ],
      ),
      body: navigationShell,
    );
  }

  Future<void> _showAboutDialog(BuildContext context) {
    return GlassDialog.show<void>(
      context: context,
      title: 'ChatApp',
      message:
          'Liquid Glass navigation chrome with readable opaque content '
          'surfaces for chats, stories and feed.',
      actions: [
        GlassDialogAction(
          label: 'OK',
          isPrimary: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _UnreadIcon extends StatelessWidget {
  const _UnreadIcon({required this.count, required this.filled});

  final int count;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      filled ? CupertinoIcons.chat_bubble_fill : CupertinoIcons.chat_bubble,
    );
    if (count <= 0) return icon;
    return Material(
      type: MaterialType.transparency,
      child: Badge(
        label: Text(count > 99 ? '99+' : '$count'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: icon,
      ),
    );
  }
}
