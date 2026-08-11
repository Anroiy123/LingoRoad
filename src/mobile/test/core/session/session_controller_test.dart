import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/session/session_store.dart';

class DelayedWriteSessionStore implements SessionStore {
  final writeStarted = Completer<void>();
  final releaseWrite = Completer<void>();

  String? _token;

  @override
  Future<void> clearToken() async {
    _token = null;
  }

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> writeToken(String token) async {
    writeStarted.complete();
    await releaseWrite.future;
    _token = token;
  }
}

class HangingReadSessionStore implements SessionStore {
  String? writtenToken;

  @override
  Future<void> clearToken() async {
    writtenToken = null;
  }

  @override
  Future<String?> readToken() => Completer<String?>().future;

  @override
  Future<void> writeToken(String token) async {
    writtenToken = token;
  }
}

class HangingClearSessionStore extends MemorySessionStore {
  HangingClearSessionStore(super.token);

  @override
  Future<void> clearToken() => Completer<void>().future;
}

void main() {
  test('restore session đã lưu', () async {
    final controller = SessionController(MemorySessionStore('stored-token'));

    await controller.restore();

    expect(controller.status, SessionStatus.authenticated);
    expect(controller.token, 'stored-token');
    expect(
      controller.placementStatus,
      PlacementOnboardingStatus.required,
    );
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
    expect(
      controller.placementStatus,
      PlacementOnboardingStatus.unknown,
    );
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

  test('logout storage bị treo timeout và không đăng xuất giả', () async {
    final store = HangingClearSessionStore('stored-token');
    final controller = SessionController(
      store,
      storeOperationTimeout: const Duration(milliseconds: 1),
    );
    await controller.restore();

    await expectLater(controller.logout(), throwsA(isA<TimeoutException>()));

    expect(controller.status, SessionStatus.authenticated);
    expect(controller.token, 'stored-token');
    expect(await store.readToken(), 'stored-token');
  });

  test('logout chờ writeToken cũ rồi xóa token khỏi store', () async {
    final store = DelayedWriteSessionStore();
    final controller = SessionController(store);
    await controller.restore();

    final authenticating = controller.authenticate(
      'delayed-token',
      checkPlacement: false,
    );
    await store.writeStarted.future;
    final loggingOut = controller.logout();

    store.releaseWrite.complete();
    await Future.wait([authenticating, loggingOut]);

    expect(controller.status, SessionStatus.unauthenticated);
    expect(controller.token, isNull);
    expect(await store.readToken(), isNull);
  });

  test('restore tải trạng thái placement completed', () async {
    final controller = SessionController(MemorySessionStore('stored-token'));
    controller.configurePlacementStatusLoader(() async => true);

    await controller.restore();

    expect(controller.status, SessionStatus.authenticated);
    expect(
      controller.placementStatus,
      PlacementOnboardingStatus.completed,
    );
  });

  test('lookup placement lỗi thử lại hữu hạn rồi chuyển sang error', () async {
    final controller = SessionController(MemorySessionStore('stored-token'));
    var calls = 0;
    controller.configurePlacementStatusLoader(() async {
      calls++;
      throw StateError('offline');
    });

    await controller.restore();

    expect(calls, 2);
    expect(
      controller.placementStatus,
      PlacementOnboardingStatus.error,
    );
  });

  test('lookup placement bị treo cũng chuyển sang error hữu hạn', () async {
    final controller = SessionController(
      MemorySessionStore('stored-token'),
      placementStatusTimeout: const Duration(milliseconds: 1),
    );
    controller.configurePlacementStatusLoader(
      () => Completer<bool>().future,
    );

    await controller.restore();

    expect(controller.status, SessionStatus.authenticated);
    expect(
      controller.placementStatus,
      PlacementOnboardingStatus.error,
    );
  });

  test('logout không bị kết quả placement cũ ghi đè', () async {
    final pending = Completer<bool>();
    final controller = SessionController(MemorySessionStore('stored-token'));
    controller.configurePlacementStatusLoader(() => pending.future);

    final restoring = controller.restore();
    await Future<void>.delayed(Duration.zero);
    expect(controller.placementStatus, PlacementOnboardingStatus.checking);

    await controller.logout();
    pending.complete(true);
    await restoring;

    expect(controller.status, SessionStatus.unauthenticated);
    expect(controller.token, isNull);
    expect(controller.placementStatus, PlacementOnboardingStatus.unknown);
  });

  test('kết quả lookup tài khoản cũ không ghi đè phiên mới', () async {
    final oldLookup = Completer<bool>();
    var calls = 0;
    final controller = SessionController(MemorySessionStore('old-token'));
    controller.configurePlacementStatusLoader(() {
      calls++;
      return calls == 1 ? oldLookup.future : Future.value(false);
    });

    final restoring = controller.restore();
    await Future<void>.delayed(Duration.zero);
    await controller.authenticate('new-token');
    expect(controller.placementStatus, PlacementOnboardingStatus.required);

    oldLookup.complete(true);
    await restoring;

    expect(controller.token, 'new-token');
    expect(controller.placementStatus, PlacementOnboardingStatus.required);
  });

  test('profile setup lookup cũ không ghi đè phiên mới hoặc retry mới',
      () async {
    final oldProfileLookup = Completer<bool>();
    var profileCalls = 0;
    final controller = SessionController(MemorySessionStore('old-token'));
    controller.configurePlacementStatusLoader(() async => true);
    controller.configureProfileSetupStatusLoader(() {
      profileCalls++;
      return profileCalls == 1 ? oldProfileLookup.future : Future.value(false);
    });

    final restoring = controller.restore();
    await Future<void>.delayed(Duration.zero);
    expect(controller.profileSetupStatus, ProfileSetupStatus.checking);

    await controller.authenticate('new-token');
    expect(controller.profileSetupStatus, ProfileSetupStatus.required);
    oldProfileLookup.complete(true);
    await restoring;

    expect(controller.token, 'new-token');
    expect(controller.profileSetupStatus, ProfileSetupStatus.required);
  });

  test('restore không giữ Splash vô hạn khi secure storage bị treo', () async {
    final store = HangingReadSessionStore();
    final controller = SessionController(
      store,
      storeReadTimeout: const Duration(milliseconds: 1),
    );

    await controller.restore();

    expect(controller.status, SessionStatus.unauthenticated);
    expect(controller.placementStatus, PlacementOnboardingStatus.unknown);

    await controller.authenticate('new-token', checkPlacement: false);
    expect(controller.status, SessionStatus.authenticated);
    expect(store.writtenToken, 'new-token');
  });
}
