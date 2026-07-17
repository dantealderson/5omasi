import 'package:flutter/material.dart';
import 'package:khomasi/theme/app_colors.dart';

/// Auth/text input. Styling comes from the theme's inputDecorationTheme;
/// this widget adds the horizontal inset and the show/hide password toggle.
class MyTextfield extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final bool enabled;

  const MyTextfield({
    super.key,
    required this.controller,
    required this.hintText,
    required this.obscureText,
    this.enabled = true,
  });

  @override
  State<MyTextfield> createState() => _MyTextfieldState();
}

class _MyTextfieldState extends State<MyTextfield> {
  late bool _isObscured;

  @override
  void initState() {
    super.initState();
    _isObscured = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0),
      child: TextField(
        controller: widget.controller,
        obscureText: _isObscured,
        enabled: widget.enabled,
        style: TextStyle(color: p.textHi, fontSize: 15),
        decoration: InputDecoration(
          hintText: widget.hintText,
          suffixIcon: widget.obscureText
              ? IconButton(
                  icon: Icon(
                    _isObscured
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: p.textMid,
                  ),
                  onPressed: widget.enabled
                      ? () => setState(() => _isObscured = !_isObscured)
                      : null,
                )
              : null,
        ),
      ),
    );
  }
}
