import '../local_db/app_database.dart';
import '../local_db/offline_queue_repository.dart';
import '../network/api_exception.dart';

typedef PendingActionHandler = Future<void> Function(PendingAction action);

/// Module 27 — "Offline Queue... مزامنة Idempotent بـ UUID".
///
/// Drains `pending_actions` in creation order, one at a time (never
/// reordered/parallelized — a `trip_status` action must apply before a
/// later `trip_cancel` on the same trip). Each `actionType` has exactly
/// ONE handler, registered once in lib/app/providers.dart, so there is a
/// single code path for "deliver this action to the backend" whether it
/// runs seconds after being enqueued (device was online) or minutes later
/// once connectivity returns — the queue never re-implements the network
/// call itself.
///
/// Idempotency reasoning (why a client-generated UUID `id` per row is
/// enough, with NO server-side Idempotency-Key header support as of
/// Phase 4): a `trip_status`/`trip_cancel` retry after a successful-but-
/// unconfirmed first attempt hits TripStateMachine's own transition
/// check — the trip is no longer in the state the transition expects, so
/// the backend rejects it with 422 rather than double-applying it. A 422
/// is therefore treated as "already handled, stop retrying" rather than a
/// transient failure — see the `permanentlyFailed` logic in `_deliver`
/// below. `sos` and `pod_upload` are naturally safe to resend (SOS just
/// re-notifies; POD's own
/// "already completed" check in UploadPodRequest gives the same 422
/// safety net as trip status).
class SyncQueueService {
  SyncQueueService({
    required OfflineQueueRepository queue,
    required Map<String, PendingActionHandler> handlers,
    this.maxRetries = 8,
  })  : _queue = queue,
        _handlers = handlers;

  final OfflineQueueRepository _queue;
  final Map<String, PendingActionHandler> _handlers;
  final int maxRetries;

  bool _flushing = false;

  /// Safe to call as often as convenient (after every enqueue, on
  /// connectivity-restored events, on a periodic timer) — re-entrant
  /// calls while a flush is already running are simply ignored rather
  /// than queued up.
  Future<void> flush() async {
    if (_flushing) {
      return;
    }

    _flushing = true;

    try {
      final actions = await _queue.pendingActions();

      for (final action in actions) {
        final delivered = await _deliver(action);

        // A transient failure (network blip, server 5xx) stops this pass
        // entirely rather than skipping ahead — a later queued action can
        // depend on this one having applied first (e.g. a cancel queued
        // right after a status change on the same trip), so strict
        // creation-order delivery matters more than draining the whole
        // queue in one pass. The next flush() call picks up right here.
        if (!delivered) {
          break;
        }
      }
    } finally {
      _flushing = false;
    }
  }

  /// Returns true if the action reached a terminal state (synced OR
  /// permanently failed) and the queue should move on to the next one;
  /// false if it's still transiently pending and the whole flush pass
  /// should stop here.
  Future<bool> _deliver(PendingAction action) async {
    final handler = _handlers[action.actionType];

    if (handler == null) {
      // Should never happen outside a bad app upgrade that removed an
      // actionType — fail loudly-ish by marking it permanently failed
      // rather than looping forever on an action nothing can process.
      await _queue.recordActionFailure(
        action.id,
        error: 'Unknown actionType: ${action.actionType}',
        retryCount: action.retryCount + 1,
        permanentlyFailed: true,
      );

      return true;
    }

    try {
      await handler(action);
      await _queue.markActionSynced(action.id);

      return true;
    } on ApiException catch (error) {
      final nextRetryCount = action.retryCount + 1;
      final permanentlyFailed = error.isValidation || nextRetryCount >= maxRetries;

      await _queue.recordActionFailure(
        action.id,
        error: error.message,
        retryCount: nextRetryCount,
        permanentlyFailed: permanentlyFailed,
      );

      return permanentlyFailed;
    } catch (error) {
      final nextRetryCount = action.retryCount + 1;
      final permanentlyFailed = nextRetryCount >= maxRetries;

      await _queue.recordActionFailure(
        action.id,
        error: error.toString(),
        retryCount: nextRetryCount,
        permanentlyFailed: permanentlyFailed,
      );

      return permanentlyFailed;
    }
  }
}
