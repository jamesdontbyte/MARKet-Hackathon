import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';

/// AppTextField provides a styled text input matching the Stitch design:
/// 10px radius, 48dp minimum touch target height, #CBD5E1 resting border,
/// and #3EC4FF active focus ring.
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final int maxLines;
  final int minLines;
  final bool autofocus;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines = 1,
    this.autofocus = false,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(MarketRadii.input);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MarketColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
        ],
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            enabled: enabled,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onChanged: onChanged,
            onFieldSubmitted: onSubmitted,
            validator: validator,
            textCapitalization: textCapitalization,
            inputFormatters: inputFormatters,
            maxLines: maxLines,
            minLines: minLines,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: enabled ? MarketColors.onSurface : MarketColors.outline,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              hintText: hintText,
              hintStyle: const TextStyle(
                fontSize: 14,
                color: MarketColors.outline,
                fontWeight: FontWeight.w400,
              ),
              helperText: helperText,
              helperStyle: const TextStyle(
                fontSize: 12,
                color: MarketColors.outline,
              ),
              errorText: errorText,
              errorStyle: const TextStyle(
                fontSize: 12,
                color: MarketColors.error,
              ),
              prefixIcon: prefixIcon,
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: enabled
                  ? MarketColors.surfaceContainerLowest
                  : MarketColors.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: borderRadius,
                borderSide: const BorderSide(color: MarketColors.fieldBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: borderRadius,
                borderSide: const BorderSide(color: MarketColors.fieldBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: borderRadius,
                borderSide: const BorderSide(
                  color: MarketColors.primaryContainer,
                  width: 2.0,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: borderRadius,
                borderSide: BorderSide(
                  color: MarketColors.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: borderRadius,
                borderSide: const BorderSide(color: MarketColors.error),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: borderRadius,
                borderSide: const BorderSide(
                  color: MarketColors.error,
                  width: 2.0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
