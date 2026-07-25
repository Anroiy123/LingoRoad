import 'package:flutter_test/flutter_test.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/session/session_store.dart';

void main() {
  test('restore session đã lưu', () async {
    final controller = SessionController(MemorySessionStore('stored-token'));

    await controller.restore();

    expect(controller.status, SessionStatus.authenticated);
    expect(controller.token, 'stored-token');
  });

  test('authenticate rồi logout cập nhật store và trạng thái', () async {
    final store = MemorySessionStore();
    final controller = SessionController(store);

    await controller.restore();
    await controller.authenticate(' new-token ');
    expect(controller.status, SessionStatus.authenticated);
    expect(await store.readToken(), 'new-token');

    await controller.logout();
    expect(controller.status, SessionStatus.unauthenticated);
    expect(await store.readToken(), isNull);
  });

  test('invalidate xóa token', () async {
    final store = MemorySessionStore('expired-token');
    final controller = SessionController(store);
    await controller.restore();

    await controller.invalidate();

    expect(controller.status, SessionStatus.unauthenticated);
    expect(controller.token, isNull);
  });
}
