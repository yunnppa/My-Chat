import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/opaque_content_surface.dart';
import '../../../core/widgets/readable_text_field.dart';
import '../../chat/presentation/chat_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _server;

  @override
  void initState() {
    super.initState();
    _server = TextEditingController(text: ref.read(apiBaseProvider));
  }

  @override
  void dispose() {
    _server.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
          'Settings',
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            OpaqueContentSurface(
              child: ListTile(
                leading: const Icon(CupertinoIcons.paintbrush),
                title: const Text('Theme'),
                subtitle: const Text('System, light or dark'),
                trailing: const Icon(CupertinoIcons.chevron_right),
                onTap: () => context.push('/settings/theme'),
              ),
            ),
            const SizedBox(height: 10),
            OpaqueContentSurface(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chat server',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Simulator: http://127.0.0.1:8080. A phone needs this '
                    'computer’s address, printed when the server starts.',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  ReadableTextField(
                    controller: _server,
                    hint: 'http://127.0.0.1:8080',
                    onSubmitted: (value) =>
                        ref.read(apiBaseProvider.notifier).setBase(value),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () => ref
                          .read(apiBaseProvider.notifier)
                          .setBase(_server.text),
                      child: const Text('Save server'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
