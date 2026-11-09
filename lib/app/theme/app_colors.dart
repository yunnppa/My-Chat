import 'package:flutter/material.dart';

/// Semantic colors that are not covered by [ColorScheme].
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.messageIncoming,
    required this.messageOutgoing,
    required this.backgroundGradient,
  });

  final Color messageIncoming;
  final Color messageOutgoing;
  final List<Color> backgroundGradient;

  static const AppColors light = AppColors(
    messageIncoming: Color(0xFFF2F4F8),
    messageOutgoing: Color(0xFF5B6CFF),
    backgroundGradient: [
      Color(0xFFE8F0FE),
      Color(0xFFEDE8F8),
      Color(0xFFE8F4FD),
    ],
  );

  static const AppColors dark = AppColors(
    messageIncoming: Color(0xFF1E2433),
    messageOutgoing: Color(0xFF4F63E8),
    backgroundGradient: [
      Color(0xFF0A0A2E),
      Color(0xFF14122E),
      Color(0xFF0D1B2A),
    ],
  );

  @override
  AppColors copyWith({
    Color? messageIncoming,
    Color? messageOutgoing,
    List<Color>? backgroundGradient,
  }) {
    return AppColors(
      messageIncoming: messageIncoming ?? this.messageIncoming,
      messageOutgoing: messageOutgoing ?? this.messageOutgoing,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      messageIncoming:
          Color.lerp(messageIncoming, other.messageIncoming, t) ??
          messageIncoming,
      messageOutgoing:
          Color.lerp(messageOutgoing, other.messageOutgoing, t) ??
          messageOutgoing,
      backgroundGradient: [
        for (var i = 0; i < backgroundGradient.length; i++)
          Color.lerp(
                backgroundGradient[i],
                other.backgroundGradient[i.clamp(
                  0,
                  other.backgroundGradient.length - 1,
                )],
                t,
              ) ??
              backgroundGradient[i],
      ],
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
