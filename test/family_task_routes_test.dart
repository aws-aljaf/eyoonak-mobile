import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fleet_saas_driver/app/providers.dart';
import 'package:fleet_saas_driver/app/router.dart';
import 'package:fleet_saas_driver/core/storage/secure_token_store.dart';

class RouteStore extends SecureTokenStore {
  @override
  Future<String?> readToken() async => null;
}

void main() {
  test('literal task destinations never resolve as numeric task IDs',
      () async {
    final container = ProviderContainer(
        overrides: [secureTokenStoreProvider.overrideWithValue(RouteStore())]);
    container.read(authControllerProvider);
    await Future<void>.delayed(Duration.zero);
    final router = container.read(routerProvider);
    for (final entry in const {
      '/family/tasks/approvals': '/family/tasks/approvals',
      '/family/tasks/weekly-report': '/family/tasks/weekly-report',
      '/family/tasks/mine': '/family/tasks/mine',
      '/family/tasks/17': '/family/tasks/:id'
    }.entries) {
      final match = router.configuration.findMatch(entry.key);
      expect(match.isError, isFalse);
      expect((match.matches.last.route as GoRoute).path, entry.value);
    }
    router.dispose();
    container.dispose();
  });
}
