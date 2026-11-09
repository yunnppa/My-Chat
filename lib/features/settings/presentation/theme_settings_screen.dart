import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/theme_mode_controller.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/opaque_content_surface.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final mode = ref.watch(themeModeControllerProvider);

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
          'Theme',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          OpaqueContentSurface(
            child: RadioGroup<ThemeMode>(
              groupValue: mode,
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(themeModeControllerProvider.notifier)
                      .setThemeMode(value);
                }
              },
              child: Column(
                children: [
                  for (final option in ThemeMode.values)
                    RadioListTile<ThemeMode>(
                      value: option,
                      title: Text(_label(option)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Glass chrome and opaque content both follow this brightness.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  String _label(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'System',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };
}
