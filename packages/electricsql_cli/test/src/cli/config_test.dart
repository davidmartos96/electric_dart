import 'package:electricsql_cli/src/config.dart';
import 'package:test/test.dart';

void main() {
  test('getConfigValue can capture `ELECTRIC_` prefixed CLI opitons', () {
    final image =
        getConfigValue<String>('ELECTRIC_IMAGE', {'image': 'electric:test'});
    final writeToPgMode = getConfigValue<String>('ELECTRIC_WRITE_TO_PG_MODE', {
      'write-to-pg-mode': 'test',
    });

    expect(image, 'electric:test');
    expect(writeToPgMode, 'test');
  });
}
