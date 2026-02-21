import 'package:flutter/services.dart';

/// Formats backup/recovery codes as `XXXX-XXXX` while uppercasing input.
class BackupCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );

    if (text.length > 8) {
      text = text.substring(0, 8);
    }

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 4) {
        buffer.write('-');
      }
      buffer.write(text[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
