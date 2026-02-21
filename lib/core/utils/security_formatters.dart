import 'package:flutter/services.dart';

/// Returns the first valid backup/recovery code found in [rawInput].
///
/// Accepts both `XXXX-XXXX` and `XXXXXXXX` forms and normalizes to
/// `XXXX-XXXX` uppercase. Returns null when no valid code is present.
String? extractFirstBackupCode(String rawInput) {
  final match = RegExp(
    r'(?<![A-Z0-9])([A-Z0-9]{4})-?([A-Z0-9]{4})(?![A-Z0-9])',
    caseSensitive: false,
  ).firstMatch(rawInput);

  if (match == null) {
    return null;
  }

  final first = match.group(1)?.toUpperCase();
  final second = match.group(2)?.toUpperCase();
  if (first == null || second == null) {
    return null;
  }

  return '$first-$second';
}

/// Formats backup/recovery codes as `XXXX-XXXX` while uppercasing input.
class BackupCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final extracted = extractFirstBackupCode(newValue.text);

    String text;
    if (extracted != null) {
      text = extracted.replaceAll('-', '');
    } else {
      text = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    }

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
