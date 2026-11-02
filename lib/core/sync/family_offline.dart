import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../network/api_exception.dart';

typedef FamilyRequest = Future<Map<String, dynamic>>
    Function(String method, String path, {Map<String, dynamic>? headers});

/// Private, bounded snapshots and pending completions; never grants points locally.
/// Only the signed-in user's namespace is accessible, including after reconnect.
class FamilyOffline extends ChangeNotifier {
  FamilyOffline({FlutterSecureStorage? storage})
      : storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage storage;
  int? userId;
  int generation = 0;
  bool offline = false, syncing = false;
  bool? hasConnection;
  void dismissSyncError() {
    syncError = null;
    notifyListeners();
  }

  String? syncError;
  Future<void> _tail = Future.value();
  Map<String, dynamic> snapshots = {};
  Map<String, dynamic> pending = {};
  Future<void> _ready = Future.value();
  int get pendingCount => pending.length;
  void setUser(int? id) {
    if (userId == id) return;
    final old = userId;
    userId = id;
    generation++;
    snapshots = {};
    pending = {};
    offline = false;
    syncing = false;
    syncError = null;
    final g = generation;
    _ready = _serial(() async {
      if (old != null && id == null) {
        try {
          await storage.delete(key: 'family.offline.$old');
        } catch (_) {}
      }
      if (id == null) return;
      try {
        final raw = await storage.read(key: 'family.offline.$id');
        if (raw != null && g == generation) {
          final d = jsonDecode(raw) as Map;
          snapshots = Map<String, dynamic>.from(d['snapshots'] as Map? ?? {});
          pending = Map<String, dynamic>.from(d['pending'] as Map? ?? {});
        }
      } catch (_) {/* An unreadable cache never blocks online use. */}
    });
  }

  Future<void> _serial(Future<void> Function() f) {
    final next = _tail.catchError((Object _) {}).then((_) => f());
    _tail = next;
    return next;
  }

  Future<void> _save(int g) async {
    final id = userId;
    if (id == null || g != generation) return;
    final encoded = jsonEncode({'snapshots': snapshots, 'pending': pending});
    await _serial(() async {
      if (g == generation) {
        await storage.write(key: 'family.offline.$id', value: encoded);
      }
    });
  }

  bool _transient(ApiException e) => e.isNetwork || (e.statusCode ?? 0) >= 500;
  String _key(String path, Map<String, dynamic>? query,
          Map<String, dynamic>? headers) =>
      jsonEncode([path, headers?['X-Family-Id'], query ?? {}]);
  bool _cacheable(String path) => const [
        '/personal/prayer',
        '/personal/adhkar',
        '/family-task-occurrences'
      ].contains(path);
  Map<String, dynamic> _clone(Map<String, dynamic> d) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(d)) as Map);
  void _overlay(Map<String, dynamic> body, Map<String, dynamic>? headers) {
    if (body['data'] is! List) return;
    for (final row in body['data'] as List) {
      if (row is Map &&
          pending.containsKey('${headers?['X-Family-Id']}:${row['id']}')) {
        row['status'] = 'pending_sync';
      }
    }
  }

  Future<Map<String, dynamic>> run(String method, String path,
      {Map<String, dynamic>? query,
      Map<String, dynamic>? headers,
      required Future<Map<String, dynamic>> Function() request}) async {
    final g = generation;
    await _ready;
    if (userId == null || g != generation) return request();
    final cache = method == 'GET' && _cacheable(path);
    final complete = method == 'POST' &&
        RegExp(r'^/family-task-occurrences/\d+/complete$').hasMatch(path);
    if (!cache && !complete) return request();
    final key = _key(path, query, headers);
    try {
      if (hasConnection == false) {
        throw const ApiException(message: 'بدون اتصال');
      }
      final result = await request();
      if (g != generation) return result;
      offline = false;
      if (cache) {
        snapshots[key] = {
          'at': DateTime.now().toUtc().toIso8601String(),
          'body': _clone(result)
        };
        while (snapshots.length > 40) {
          snapshots.remove(snapshots.keys.first);
        }
        try {
          await _save(g);
        } catch (_) {}
        _overlay(result, headers);
      }
      notifyListeners();
      return result;
    } on ApiException catch (e) {
      if (g != generation) rethrow;
      if (e.statusCode == 401 || e.statusCode == 403) {
        snapshots = {};
        pending = {};
        try {
          await _save(g);
        } catch (_) {}
        notifyListeners();
        rethrow;
      }
      if (!_transient(e)) rethrow;
      offline = true;
      if (cache) {
        final saved = snapshots[key] as Map?;
        final at = DateTime.tryParse(saved?['at'] as String? ?? '');
        if (saved != null &&
            at != null &&
            DateTime.now().toUtc().difference(at).inDays < 7) {
          final result =
              _clone(Map<String, dynamic>.from(saved['body'] as Map));
          _overlay(result, headers);
          result['_offline'] = true;
          result['_cached_at'] = saved['at'];
          if (result['data'] is Map) {
            result['data']['_offline'] = true;
            result['data']['_cached_at'] = saved['at'];
          }
          notifyListeners();
          return result;
        }
      }
      if (complete) {
        final id = int.parse(path.split('/')[2]);
        Map<String, dynamic>? found;
        for (final entry in snapshots.entries) {
          final info = jsonDecode(entry.key) as List;
          if (info[0] != '/family-task-occurrences' ||
              info[1] != headers?['X-Family-Id']) {
            continue;
          }
          for (final row in (entry.value['body']['data'] as List? ?? [])) {
            if (row['id'] == id &&
                ['pending', 'pending_sync'].contains(row['status'])) {
              found = Map<String, dynamic>.from(row as Map);
            }
          }
        }
        if (found != null) {
          final pk = '${headers?['X-Family-Id']}:$id';
          if (pending.length >= 50 && !pending.containsKey(pk)) {
            throw const ApiException(
                message:
                    'قائمة الإنجازات غير المزامنة ممتلئة. اتصل بالشبكة أولاً.');
          }
          pending[pk] = {
            'path': path,
            'headers': headers,
            'at': DateTime.now().toUtc().toIso8601String()
          };
          await _save(g);
          notifyListeners();
          return {
            'success': true,
            'data': {...found, 'status': 'pending_sync'}
          };
        }
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> flush(FamilyRequest request) async {
    final g = generation;
    await _ready;
    if (userId == null || g != generation || syncing || hasConnection == false) { return; }
    syncing = true;
    notifyListeners();
    try {
      for (final key in pending.keys.toList()) {
        if (g != generation) return;
        final item = pending[key] as Map;
        try {
          final acknowledged = await request('POST', item['path'] as String,
              headers: item['headers'] == null
                  ? null
                  : Map<String, dynamic>.from(item['headers'] as Map));
          if (g != generation) return;
          final scope = (item['headers'] as Map?)?['X-Family-Id'];
          final id = int.tryParse((item['path'] as String).split('/')[2]);
          for (final entry in snapshots.entries) {
            final info = jsonDecode(entry.key) as List;
            if (info[0] != '/family-task-occurrences' || info[1] != scope) { continue; }
            final rows = entry.value['body']['data'] as List? ?? [];
            for (var i = 0; i < rows.length; i++) {
              if (rows[i]['id'] == id && acknowledged['data'] is Map) { rows[i] = acknowledged['data']; }
            }
          }
          pending.remove(key);
          offline = false;
          await _save(g);
        } on ApiException catch (e) {
          if (g != generation) return;
          if (_transient(e)) {
            offline = true;
            break;
          }
          // A denied/changed task is never silently re-created or awarded points locally.
          pending.remove(key);
          snapshots = {};
          syncError = 'تعذر اعتماد أحد الإنجازات: ${e.message}';
          if (e.statusCode == 401 || e.statusCode == 403) pending = {};
          await _save(g);
          break;
        }
      }
    } finally {
      if (g == generation) {
        syncing = false;
        notifyListeners();
      }
    }
  }
}
