import 'package:flutter/material.dart';

/// Text field without the yellow spell-check underline.
class ReadableTextField extends StatelessWidget {
  const ReadableTextField({
    required this.controller,
    required this.hint,
    super.key,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction = TextInputAction.send,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );

    return Material(
      type: MaterialType.transparency,
      child: TextField(
        controller: controller,
        autocorrect: false,
        enableSuggestions: false,
        spellCheckConfiguration: SpellCheckConfiguration.disabled(),
        textInputAction: textInputAction,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          decoration: TextDecoration.none,
          color: scheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: scheme.surface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: scheme.primary),
          ),
        ),
        onChanged: onChanged,
        onSubmitted: onSubmitted,
      ),
    );
  }
}
