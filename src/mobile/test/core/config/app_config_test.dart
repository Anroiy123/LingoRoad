import 'package:flutter_test/flutter_test.dart';
import 'package:lingoroad_mobile/core/config/app_config.dart';

void main() {
  test('chuẩn hóa base URL và resolve path', () {
    final config = AppConfig(apiBaseUrl: ' http://localhost:5000/// ');

    expect(config.apiBaseUrl, 'http://localhost:5000');
    expect(config.resolve('health').toString(), 'http://localhost:5000/health');
  });

  test('từ chối base URL không hợp lệ', () {
    expect(
      () => AppConfig(apiBaseUrl: 'localhost:5000'),
      throwsArgumentError,
    );
  });
}
