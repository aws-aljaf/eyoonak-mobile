import 'package:fleet_saas_driver/app/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_saas_driver/features/auth/application/auth_controller.dart';
import 'package:fleet_saas_driver/features/auth/application/auth_state.dart';
import 'package:fleet_saas_driver/features/auth/data/auth_api.dart';
import 'package:fleet_saas_driver/features/auth/data/driver_user.dart';
import 'package:fleet_saas_driver/core/storage/secure_token_store.dart';
import 'package:fleet_saas_driver/core/network/api_client.dart';

class RegistrationStore extends SecureTokenStore {
  String? token;
  String? device;
  @override
  Future<String?> readToken() async => token;
  @override
  Future<String?> readDeviceUuid() async => device;
  @override
  Future<void> saveDeviceUuid(String uuid) async {
    device = uuid;
  }

  @override
  Future<void> saveToken(String value) async {
    token = value;
  }

  @override
  Future<void> saveDriverId(int? id) async {}
}

class RegistrationApi extends AuthApi {
  RegistrationApi() : super(ApiClient(getToken: () async => null));
  Map<String, dynamic>? sent;
  @override
  Future<Map<String, dynamic>> registerFamily(
      {required Map<String, dynamic> details,
      required String deviceUuid,
      required String deviceName,
      required String appVersion}) async {
    sent = {...details, 'device_uuid': deviceUuid, 'app_version': appVersion};
    return {'token': 'synthetic-test-token'};
  }

  @override
  Future<DriverUser> me() async => const DriverUser(id: 4, name: 'Test parent', hasFamilyMembership: true);
}

void main() {
  test('family registration persists the session and refreshes authoritative family access', () async {
    final api = RegistrationApi(), store = RegistrationStore();
    final controller = AuthController(api, store);
    await Future<void>.delayed(Duration.zero);
    await controller.registerFamily({
      'name': 'Test parent',
      'phone': '0000000000',
      'password': 'synthetic-password',
      'password_confirmation': 'synthetic-password'
    });
    expect(controller.state.status, AuthStatus.authenticated);
    expect(controller.state.user?.hasFamilyAccess, true);
    expect(store.token, 'synthetic-test-token');
    expect(api.sent?['device_uuid'], store.device);
    expect(api.sent?['app_version'], kAppVersion);
    controller.dispose();
  });
}
