import 'package:flutter/material.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/theme/theme_mode_controller.dart';
import 'features/chat/presentation/push_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensureFirebaseMessaging();

  final prefs = await SharedPreferences.getInstance();
  final qualityPersistence = GlassQualityPersistence.auto();
  await LiquidGlassWidgets.initialize(qualityPersistence: qualityPersistence);

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: LiquidGlassWidgets.wrap(
        child: const ChatApp(),
        adaptiveQuality: true,
        qualityPersistence: qualityPersistence,
        brightnessResolver: Theme.maybeBrightnessOf,
        theme: GlassThemePresets.tintedBrand(const Color(0xFF5B6CFF)),
      ),
    ),
  );
}
