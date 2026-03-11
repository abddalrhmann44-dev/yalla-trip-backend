import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/constants.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool showToggle;       // auto eye icon for passwords
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final int? maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final bool readOnly;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final String? helperText;

  const CustomTextField({
    Key? key,
    required this.controller,
    required this.label,
    required this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText        = false,
    this.showToggle         = false,
    this.keyboardType       = TextInputType.text,
    this.textInputAction    = TextInputAction.next,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.maxLines           = 1,
    this.maxLength,
    this.inputFormatters,
    this.enabled            = true,
    this.readOnly           = false,
    this.onTap,
    this.focusNode,
    this.helperText,
  }) : super(key: key);

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscure = true;
  bool _isFocused = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Label ──
        Text(
          widget.label,
          style: AppTextStyles.labelLarge,
        ),
        const SizedBox(height: 8),

        // ── Field ──
        TextFormField(
          controller: widget.controller,
          obscureText: widget.showToggle ? _obscure : widget.obscureText,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          maxLines: widget.obscureText || widget.showToggle ? 1 : widget.maxLines,
          maxLength: widget.maxLength,
          inputFormatters: widget.inputFormatters,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          onTap: widget.onTap,
          focusNode: _focusNode,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(
              color: AppColors.textLight,
              fontSize: 15,
            ),
            helperText: widget.helperText,
            helperStyle: AppTextStyles.bodySmall,
            counterText: '',

            prefixIcon: widget.prefixIcon != null
                ? Icon(
                    widget.prefixIcon,
                    color: _isFocused
                        ? AppColors.primary
                        : AppColors.textHint,
                    size: 20,
                  )
                : null,

            suffixIcon: widget.showToggle
                ? GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
                    child: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textHint,
                      size: 20,
                    ),
                  )
                : widget.suffixIcon,

            filled: true,
            fillColor: widget.enabled
                ? AppColors.white
                : AppColors.background,

            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),

            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: const BorderSide(
                  color: AppColors.border, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: const BorderSide(
                  color: AppColors.border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: const BorderSide(
                  color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: const BorderSide(
                  color: AppColors.error, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: const BorderSide(
                  color: AppColors.error, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: const BorderSide(
                  color: AppColors.divider, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
