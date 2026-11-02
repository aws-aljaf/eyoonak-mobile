import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_saas_driver/core/network/api_client.dart';
import 'package:fleet_saas_driver/core/network/api_exception.dart';
import 'package:fleet_saas_driver/core/storage/secure_token_store.dart';
import 'package:fleet_saas_driver/features/auth/application/auth_controller.dart';
import 'package:fleet_saas_driver/features/auth/application/auth_state.dart';
import 'package:fleet_saas_driver/features/auth/data/auth_api.dart';
import 'package:fleet_saas_driver/features/auth/data/driver_user.dart';

class RestoreStore extends SecureTokenStore {
  bool cleared = false;
  @override Future<String?> readToken() async => 'existing-test-session';
  @override Future<void> clearAll() async { cleared = true; }
}
class UnavailableAuth extends AuthApi {
  UnavailableAuth(this.status):super(ApiClient(getToken: () async => null));
  final int? status;
  @override Future<DriverUser> me() async => throw ApiException(message: 'unavailable', statusCode: status);
}
class NewAccountStore extends RestoreStore {
  String? saved;
  @override Future<String?> readToken() async => null;
  @override Future<String?> readDeviceUuid() async => 'test-device';
  @override Future<void> saveToken(String token) async { saved = token; }
  @override Future<void> saveDriverId(int? id) async {}
}
class ConfirmedSignup extends UnavailableAuth {
  ConfirmedSignup():super(503);
  int creations = 0;
  @override Future<Map<String,dynamic>> registerFamily({required Map<String,dynamic> details, required String deviceUuid, required String deviceName, required String appVersion}) async {
    creations++;
    return {'token': 'confirmed-test-session', 'user': {'id': 8, 'name': 'Parent', 'phone': '07701234567'}, 'family': {'id': 2}};
  }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('confirmed signup survives a temporary profile fetch failure without registering again', () async {
    final store = NewAccountStore();
    final api = ConfirmedSignup();
    final controller = AuthController(api, store);
    await controller.stream.firstWhere((state) => state.status == AuthStatus.unauthenticated);
    await controller.registerFamily({'phone': '07701234567'});
    expect(controller.state.isAuthenticated, isTrue);
    expect(controller.state.user?.hasFamilyMembership, isTrue);
    expect(api.creations, 1);
    expect(store.saved, 'confirmed-test-session');
    expect(store.cleared, isFalse);
    controller.dispose();
  });
  for (final status in <int?>[null, 503]) {
    test('session survives temporary restore failure $status', () async {
      final store = RestoreStore();
      final controller = AuthController(UnavailableAuth(status), store);
      await controller.stream.firstWhere((state) => state.status == AuthStatus.unauthenticated);
      expect(store.cleared, isFalse);
      expect(controller.state.isAuthenticated, isFalse);
      expect(controller.state.errorMessage, contains('الجلسة'));
      controller.dispose();
    });
  }
  test('invalid session is still removed on unauthorized response', () async {
    final store = RestoreStore();
    final controller = AuthController(UnavailableAuth(401), store);
    await controller.stream.firstWhere((state) => state.status == AuthStatus.unauthenticated);
    expect(store.cleared, isTrue);
    controller.dispose();
  });
}
