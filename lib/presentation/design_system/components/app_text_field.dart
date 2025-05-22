import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

/// AppTextField provides a consistent text input component across the application.
/// It supports different variants, states, and input types.
class AppTextField extends StatefulWidget {
  final String? label;
  final String? placeholder;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final EdgeInsets contentPadding;
  final Widget? prefix;
  final Widget? suffix;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextFieldVariant variant;
  final BoxConstraints? prefixIconConstraints;
  final BoxConstraints? suffixIconConstraints;
  final String? initialValue;
  final bool required;
  final AutovalidateMode autovalidateMode;
  final String? Function(String?)? validator;
  final bool expands;
  final TextAlignVertical? textAlignVertical;
  final TextAlign textAlign;
  final bool isDense;

  const AppTextField({
    Key? key,
    this.label,
    this.placeholder,
    this.helperText,
    this.errorText,
    this.controller,
    this.focusNode,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.done,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.contentPadding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.prefix,
    this.suffix,
    this.prefixIcon,
    this.suffixIcon,
    this.variant = TextFieldVariant.outlined,
    this.prefixIconConstraints,
    this.suffixIconConstraints,
    this.initialValue,
    this.required = false,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.validator,
    this.expands = false,
    this.textAlignVertical,
    this.textAlign = TextAlign.start,
    this.isDense = false,
  }) : super(key: key);

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _obscureText = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? TextEditingController(text: widget.initialValue);
    _focusNode = widget.focusNode ?? FocusNode();
    _obscureText = widget.obscureText;

    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.removeListener(_handleFocusChange);
      _focusNode.dispose();
    }
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  void _toggleObscureText() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Determine if we need to show a password toggle
    Widget? effectiveSuffixIcon = widget.suffixIcon;
    if (widget.obscureText && effectiveSuffixIcon == null) {
      effectiveSuffixIcon = IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility_off : Icons.visibility,
          color: AppColors.grey300,
          size: 20,
        ),
        onPressed: _toggleObscureText,
        splashRadius: 20,
      );
    }

    // Build the text field based on variant
    Widget textField;
    switch (widget.variant) {
      case TextFieldVariant.outlined:
        textField = _buildOutlinedTextField(effectiveSuffixIcon);
        break;
      case TextFieldVariant.filled:
        textField = _buildFilledTextField(effectiveSuffixIcon);
        break;
      case TextFieldVariant.underlined:
        textField = _buildUnderlinedTextField(effectiveSuffixIcon);
        break;
    }

    // Add label if provided
    if (widget.label != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                widget.label!,
                style: TextStyle(
                  color: widget.errorText != null
                      ? AppColors.error
                      : widget.enabled
                          ? AppColors.textSecondary
                          : AppColors.textDisabled,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (widget.required)
                Text(
                  ' *',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          SizedBox(height: 6),
          textField,
          if (widget.helperText != null || widget.errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                widget.errorText ?? widget.helperText!,
                style: TextStyle(
                  color: widget.errorText != null
                      ? AppColors.error
                      : AppColors.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
        ],
      );
    }

    return textField;
  }

  Widget _buildOutlinedTextField(Widget? effectiveSuffixIcon) {
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      obscureText: _obscureText,
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      onChanged: widget.onChanged,
      onEditingComplete: widget.onEditingComplete,
      onFieldSubmitted: widget.onSubmitted,
      inputFormatters: widget.inputFormatters,
      textCapitalization: widget.textCapitalization,
      expands: widget.expands,
      textAlignVertical: widget.textAlignVertical,
      textAlign: widget.textAlign,
      style: TextStyle(
        color: widget.enabled ? AppColors.textPrimary : AppColors.textDisabled,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        isDense: widget.isDense,
        filled: true,
        fillColor: widget.enabled ? AppColors.white : AppColors.surfaceLight,
        hintText: widget.placeholder,
        hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
        errorText: widget.errorText,
        errorStyle: const TextStyle(height: 0, fontSize: 0),
        helperText: null,
        helperStyle: const TextStyle(height: 0, fontSize: 0),
        contentPadding: widget.contentPadding,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: AppColors.border),
        ),
        prefixIcon: widget.prefixIcon,
        suffixIcon: effectiveSuffixIcon,
        prefix: widget.prefix,
        suffix: widget.suffix,
        prefixIconConstraints: widget.prefixIconConstraints,
        suffixIconConstraints: widget.suffixIconConstraints,
      ),
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
    );
  }

  Widget _buildFilledTextField(Widget? effectiveSuffixIcon) {
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      obscureText: _obscureText,
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      onChanged: widget.onChanged,
      onEditingComplete: widget.onEditingComplete,
      onFieldSubmitted: widget.onSubmitted,
      inputFormatters: widget.inputFormatters,
      textCapitalization: widget.textCapitalization,
      expands: widget.expands,
      textAlignVertical: widget.textAlignVertical,
      textAlign: widget.textAlign,
      style: TextStyle(
        color: widget.enabled ? AppColors.textPrimary : AppColors.textDisabled,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        isDense: widget.isDense,
        filled: true,
        fillColor: widget.enabled ? AppColors.surfaceLight : AppColors.grey100,
        hintText: widget.placeholder,
        hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
        errorText: widget.errorText,
        errorStyle: const TextStyle(height: 0, fontSize: 0),
        helperText: null,
        helperStyle: const TextStyle(height: 0, fontSize: 0),
        contentPadding: widget.contentPadding,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: AppColors.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: AppColors.error),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide.none,
        ),
        prefixIcon: widget.prefixIcon,
        suffixIcon: effectiveSuffixIcon,
        prefix: widget.prefix,
        suffix: widget.suffix,
        prefixIconConstraints: widget.prefixIconConstraints,
        suffixIconConstraints: widget.suffixIconConstraints,
      ),
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
    );
  }

  Widget _buildUnderlinedTextField(Widget? effectiveSuffixIcon) {
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      obscureText: _obscureText,
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      onChanged: widget.onChanged,
      onEditingComplete: widget.onEditingComplete,
      onFieldSubmitted: widget.onSubmitted,
      inputFormatters: widget.inputFormatters,
      textCapitalization: widget.textCapitalization,
      expands: widget.expands,
      textAlignVertical: widget.textAlignVertical,
      textAlign: widget.textAlign,
      style: TextStyle(
        color: widget.enabled ? AppColors.textPrimary : AppColors.textDisabled,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        isDense: widget.isDense,
        filled: false,
        hintText: widget.placeholder,
        hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
        errorText: widget.errorText,
        errorStyle: const TextStyle(height: 0, fontSize: 0),
        helperText: null,
        helperStyle: const TextStyle(height: 0, fontSize: 0),
        contentPadding: widget.contentPadding,
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
        disabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.border),
        ),
        prefixIcon: widget.prefixIcon,
        suffixIcon: effectiveSuffixIcon,
        prefix: widget.prefix,
        suffix: widget.suffix,
        prefixIconConstraints: widget.prefixIconConstraints,
        suffixIconConstraints: widget.suffixIconConstraints,
      ),
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
    );
  }
}

/// Text field variants for different use cases
enum TextFieldVariant {
  outlined, // Text field with outline border
  filled, // Text field with filled background
  underlined, // Text field with bottom border only
}
