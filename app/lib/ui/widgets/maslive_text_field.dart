import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui_kit/tokens/maslive_tokens.dart';

/// Champ de saisie unique de l'app — remplace les `TextFormField` /
/// `InputDecoration` redessines par ecran (bordure, rayon, couleur de focus
/// tous differents d'un formulaire a l'autre).
class MasliveTextField extends StatelessWidget {
  const MasliveTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.helperText,
    this.icon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.minLines,
    this.readOnly = false,
    this.enabled = true,
    this.inputFormatters,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.initialValue,
  });

  final TextEditingController? controller;
  final String label;
  final String? hint;
  final String? helperText;
  final IconData? icon;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final int maxLines;
  final int? minLines;
  final bool readOnly;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final bool autocorrect;
  final bool enableSuggestions;
  final String? initialValue;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onChanged: onChanged,
      maxLines: obscureText ? 1 : maxLines,
      minLines: obscureText ? null : minLines,
      readOnly: readOnly,
      enabled: enabled,
      autofocus: autofocus,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: MasliveTokens.text, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        prefixIcon: icon == null ? null : Icon(icon, color: MasliveTokens.textFaint, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: enabled ? MasliveTokens.surface : MasliveTokens.bg,
        labelStyle: const TextStyle(color: MasliveTokens.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MasliveTokens.rM),
          borderSide: BorderSide(color: MasliveTokens.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MasliveTokens.rM),
          borderSide: BorderSide(color: MasliveTokens.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MasliveTokens.rM),
          borderSide: const BorderSide(color: MasliveTokens.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MasliveTokens.rM),
          borderSide: const BorderSide(color: MasliveTokens.danger),
        ),
      ),
    );
  }
}
