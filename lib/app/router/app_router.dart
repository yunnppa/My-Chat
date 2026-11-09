import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/presentation/chats_screen.dart';
import '../../features/chat/presentation/conversation_screen.dart';
import '../../features/chat/presentation/friends_screen.dart';
import '../../features/chat/presentation/new_chat_screen.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/theme_settings_screen.dart';
import '../../features/stories/presentation/stories_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home/chats',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/chats',
                name: 'chats',
                builder: (context, state) => const ChatsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/stories',
                name: 'stories',
                builder: (context, state) => const StoriesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/profile',
                name: 'profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/new-chat',
        name: 'new-chat',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NewChatScreen(),
      ),
      GoRoute(
        path: '/friends',
        name: 'friends',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const FriendsScreen(),
      ),
      GoRoute(
        path: '/chat/:chatId',
        name: 'conversation',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final chatId = state.pathParameters['chatId'] ?? 'unknown';
          final title = state.uri.queryParameters['title'] ?? 'Chat';
          return ConversationScreen(chatId: chatId, title: title);
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'theme',
            name: 'theme-settings',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const ThemeSettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
