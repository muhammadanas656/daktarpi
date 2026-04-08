import 'package:aeviapulse/core/utils/security_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractFirstBackupCode', () {
    test('extracts first hyphenated code from multiline block', () {
      const block = '''
      Backup codes:
      abcd-1234
      wxyz-9999
      ''';

      expect(extractFirstBackupCode(block), 'ABCD-1234');
    });

    test('extracts first compact code and normalizes hyphen', () {
      const block = 'Codes: qwer5678 then ZXCV-1111';

      expect(extractFirstBackupCode(block), 'QWER-5678');
    });

    test('returns null when no valid code exists', () {
      expect(extractFirstBackupCode('no backup code here'), isNull);
    });
  });

  group('BackupCodeFormatter', () {
    test('formats manual input as XXXX-XXXX', () {
      final formatter = BackupCodeFormatter();
      final value = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(text: 'abcd1234'),
      );

      expect(value.text, 'ABCD-1234');
    });

    test('extracts first valid code from pasted block', () {
      final formatter = BackupCodeFormatter();
      final value = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(text: 'codes: AAAA-1111 BBBB-2222'),
      );

      expect(value.text, 'AAAA-1111');
    });
  });
}
