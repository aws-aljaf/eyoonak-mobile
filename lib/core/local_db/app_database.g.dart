// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PendingActionsTable extends PendingActions
    with TableInfo<$PendingActionsTable, PendingAction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingActionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _actionTypeMeta =
      const VerificationMeta('actionType');
  @override
  late final GeneratedColumn<String> actionType = GeneratedColumn<String>(
      'action_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<int> tripId = GeneratedColumn<int>(
      'trip_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _stopIdMeta = const VerificationMeta('stopId');
  @override
  late final GeneratedColumn<int> stopId = GeneratedColumn<int>(
      'stop_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _payloadJsonMeta =
      const VerificationMeta('payloadJson');
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _retryCountMeta =
      const VerificationMeta('retryCount');
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
      'retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        actionType,
        tripId,
        stopId,
        payloadJson,
        createdAt,
        status,
        retryCount,
        lastError
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_actions';
  @override
  VerificationContext validateIntegrity(Insertable<PendingAction> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('action_type')) {
      context.handle(
          _actionTypeMeta,
          actionType.isAcceptableOrUnknown(
              data['action_type']!, _actionTypeMeta));
    } else if (isInserting) {
      context.missing(_actionTypeMeta);
    }
    if (data.containsKey('trip_id')) {
      context.handle(_tripIdMeta,
          tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta));
    }
    if (data.containsKey('stop_id')) {
      context.handle(_stopIdMeta,
          stopId.isAcceptableOrUnknown(data['stop_id']!, _stopIdMeta));
    }
    if (data.containsKey('payload_json')) {
      context.handle(
          _payloadJsonMeta,
          payloadJson.isAcceptableOrUnknown(
              data['payload_json']!, _payloadJsonMeta));
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('retry_count')) {
      context.handle(
          _retryCountMeta,
          retryCount.isAcceptableOrUnknown(
              data['retry_count']!, _retryCountMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingAction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingAction(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      actionType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}action_type'])!,
      tripId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}trip_id']),
      stopId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}stop_id']),
      payloadJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_json'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      retryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}retry_count'])!,
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
    );
  }

  @override
  $PendingActionsTable createAlias(String alias) {
    return $PendingActionsTable(attachedDatabase, alias);
  }
}

class PendingAction extends DataClass implements Insertable<PendingAction> {
  final String id;
  final String actionType;
  final int? tripId;
  final int? stopId;
  final String payloadJson;
  final DateTime createdAt;
  final String status;
  final int retryCount;
  final String? lastError;
  const PendingAction(
      {required this.id,
      required this.actionType,
      this.tripId,
      this.stopId,
      required this.payloadJson,
      required this.createdAt,
      required this.status,
      required this.retryCount,
      this.lastError});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['action_type'] = Variable<String>(actionType);
    if (!nullToAbsent || tripId != null) {
      map['trip_id'] = Variable<int>(tripId);
    }
    if (!nullToAbsent || stopId != null) {
      map['stop_id'] = Variable<int>(stopId);
    }
    map['payload_json'] = Variable<String>(payloadJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['status'] = Variable<String>(status);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  PendingActionsCompanion toCompanion(bool nullToAbsent) {
    return PendingActionsCompanion(
      id: Value(id),
      actionType: Value(actionType),
      tripId:
          tripId == null && nullToAbsent ? const Value.absent() : Value(tripId),
      stopId:
          stopId == null && nullToAbsent ? const Value.absent() : Value(stopId),
      payloadJson: Value(payloadJson),
      createdAt: Value(createdAt),
      status: Value(status),
      retryCount: Value(retryCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory PendingAction.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingAction(
      id: serializer.fromJson<String>(json['id']),
      actionType: serializer.fromJson<String>(json['actionType']),
      tripId: serializer.fromJson<int?>(json['tripId']),
      stopId: serializer.fromJson<int?>(json['stopId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      status: serializer.fromJson<String>(json['status']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'actionType': serializer.toJson<String>(actionType),
      'tripId': serializer.toJson<int?>(tripId),
      'stopId': serializer.toJson<int?>(stopId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'status': serializer.toJson<String>(status),
      'retryCount': serializer.toJson<int>(retryCount),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  PendingAction copyWith(
          {String? id,
          String? actionType,
          Value<int?> tripId = const Value.absent(),
          Value<int?> stopId = const Value.absent(),
          String? payloadJson,
          DateTime? createdAt,
          String? status,
          int? retryCount,
          Value<String?> lastError = const Value.absent()}) =>
      PendingAction(
        id: id ?? this.id,
        actionType: actionType ?? this.actionType,
        tripId: tripId.present ? tripId.value : this.tripId,
        stopId: stopId.present ? stopId.value : this.stopId,
        payloadJson: payloadJson ?? this.payloadJson,
        createdAt: createdAt ?? this.createdAt,
        status: status ?? this.status,
        retryCount: retryCount ?? this.retryCount,
        lastError: lastError.present ? lastError.value : this.lastError,
      );
  PendingAction copyWithCompanion(PendingActionsCompanion data) {
    return PendingAction(
      id: data.id.present ? data.id.value : this.id,
      actionType:
          data.actionType.present ? data.actionType.value : this.actionType,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      stopId: data.stopId.present ? data.stopId.value : this.stopId,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      status: data.status.present ? data.status.value : this.status,
      retryCount:
          data.retryCount.present ? data.retryCount.value : this.retryCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingAction(')
          ..write('id: $id, ')
          ..write('actionType: $actionType, ')
          ..write('tripId: $tripId, ')
          ..write('stopId: $stopId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, actionType, tripId, stopId, payloadJson,
      createdAt, status, retryCount, lastError);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingAction &&
          other.id == this.id &&
          other.actionType == this.actionType &&
          other.tripId == this.tripId &&
          other.stopId == this.stopId &&
          other.payloadJson == this.payloadJson &&
          other.createdAt == this.createdAt &&
          other.status == this.status &&
          other.retryCount == this.retryCount &&
          other.lastError == this.lastError);
}

class PendingActionsCompanion extends UpdateCompanion<PendingAction> {
  final Value<String> id;
  final Value<String> actionType;
  final Value<int?> tripId;
  final Value<int?> stopId;
  final Value<String> payloadJson;
  final Value<DateTime> createdAt;
  final Value<String> status;
  final Value<int> retryCount;
  final Value<String?> lastError;
  final Value<int> rowid;
  const PendingActionsCompanion({
    this.id = const Value.absent(),
    this.actionType = const Value.absent(),
    this.tripId = const Value.absent(),
    this.stopId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingActionsCompanion.insert({
    required String id,
    required String actionType,
    this.tripId = const Value.absent(),
    this.stopId = const Value.absent(),
    required String payloadJson,
    required DateTime createdAt,
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        actionType = Value(actionType),
        payloadJson = Value(payloadJson),
        createdAt = Value(createdAt);
  static Insertable<PendingAction> custom({
    Expression<String>? id,
    Expression<String>? actionType,
    Expression<int>? tripId,
    Expression<int>? stopId,
    Expression<String>? payloadJson,
    Expression<DateTime>? createdAt,
    Expression<String>? status,
    Expression<int>? retryCount,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (actionType != null) 'action_type': actionType,
      if (tripId != null) 'trip_id': tripId,
      if (stopId != null) 'stop_id': stopId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (createdAt != null) 'created_at': createdAt,
      if (status != null) 'status': status,
      if (retryCount != null) 'retry_count': retryCount,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingActionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? actionType,
      Value<int?>? tripId,
      Value<int?>? stopId,
      Value<String>? payloadJson,
      Value<DateTime>? createdAt,
      Value<String>? status,
      Value<int>? retryCount,
      Value<String?>? lastError,
      Value<int>? rowid}) {
    return PendingActionsCompanion(
      id: id ?? this.id,
      actionType: actionType ?? this.actionType,
      tripId: tripId ?? this.tripId,
      stopId: stopId ?? this.stopId,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (actionType.present) {
      map['action_type'] = Variable<String>(actionType.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<int>(tripId.value);
    }
    if (stopId.present) {
      map['stop_id'] = Variable<int>(stopId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingActionsCompanion(')
          ..write('id: $id, ')
          ..write('actionType: $actionType, ')
          ..write('tripId: $tripId, ')
          ..write('stopId: $stopId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingGpsPointsTable extends PendingGpsPoints
    with TableInfo<$PendingGpsPointsTable, PendingGpsPoint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingGpsPointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<int> tripId = GeneratedColumn<int>(
      'trip_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
      'lat', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
      'lng', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _speedKphMeta =
      const VerificationMeta('speedKph');
  @override
  late final GeneratedColumn<double> speedKph = GeneratedColumn<double>(
      'speed_kph', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _headingDegMeta =
      const VerificationMeta('headingDeg');
  @override
  late final GeneratedColumn<double> headingDeg = GeneratedColumn<double>(
      'heading_deg', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _accuracyMMeta =
      const VerificationMeta('accuracyM');
  @override
  late final GeneratedColumn<double> accuracyM = GeneratedColumn<double>(
      'accuracy_m', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _recordedAtMeta =
      const VerificationMeta('recordedAt');
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
      'recorded_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
      'synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        tripId,
        lat,
        lng,
        speedKph,
        headingDeg,
        accuracyM,
        recordedAt,
        synced
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_gps_points';
  @override
  VerificationContext validateIntegrity(Insertable<PendingGpsPoint> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('trip_id')) {
      context.handle(_tripIdMeta,
          tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta));
    }
    if (data.containsKey('lat')) {
      context.handle(
          _latMeta, lat.isAcceptableOrUnknown(data['lat']!, _latMeta));
    } else if (isInserting) {
      context.missing(_latMeta);
    }
    if (data.containsKey('lng')) {
      context.handle(
          _lngMeta, lng.isAcceptableOrUnknown(data['lng']!, _lngMeta));
    } else if (isInserting) {
      context.missing(_lngMeta);
    }
    if (data.containsKey('speed_kph')) {
      context.handle(_speedKphMeta,
          speedKph.isAcceptableOrUnknown(data['speed_kph']!, _speedKphMeta));
    }
    if (data.containsKey('heading_deg')) {
      context.handle(
          _headingDegMeta,
          headingDeg.isAcceptableOrUnknown(
              data['heading_deg']!, _headingDegMeta));
    }
    if (data.containsKey('accuracy_m')) {
      context.handle(_accuracyMMeta,
          accuracyM.isAcceptableOrUnknown(data['accuracy_m']!, _accuracyMMeta));
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
          _recordedAtMeta,
          recordedAt.isAcceptableOrUnknown(
              data['recorded_at']!, _recordedAtMeta));
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    if (data.containsKey('synced')) {
      context.handle(_syncedMeta,
          synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingGpsPoint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingGpsPoint(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      tripId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}trip_id']),
      lat: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}lat'])!,
      lng: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}lng'])!,
      speedKph: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}speed_kph']),
      headingDeg: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}heading_deg']),
      accuracyM: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}accuracy_m']),
      recordedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}recorded_at'])!,
      synced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}synced'])!,
    );
  }

  @override
  $PendingGpsPointsTable createAlias(String alias) {
    return $PendingGpsPointsTable(attachedDatabase, alias);
  }
}

class PendingGpsPoint extends DataClass implements Insertable<PendingGpsPoint> {
  final String id;
  final int? tripId;
  final double lat;
  final double lng;
  final double? speedKph;
  final double? headingDeg;
  final double? accuracyM;
  final DateTime recordedAt;
  final bool synced;
  const PendingGpsPoint(
      {required this.id,
      this.tripId,
      required this.lat,
      required this.lng,
      this.speedKph,
      this.headingDeg,
      this.accuracyM,
      required this.recordedAt,
      required this.synced});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || tripId != null) {
      map['trip_id'] = Variable<int>(tripId);
    }
    map['lat'] = Variable<double>(lat);
    map['lng'] = Variable<double>(lng);
    if (!nullToAbsent || speedKph != null) {
      map['speed_kph'] = Variable<double>(speedKph);
    }
    if (!nullToAbsent || headingDeg != null) {
      map['heading_deg'] = Variable<double>(headingDeg);
    }
    if (!nullToAbsent || accuracyM != null) {
      map['accuracy_m'] = Variable<double>(accuracyM);
    }
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  PendingGpsPointsCompanion toCompanion(bool nullToAbsent) {
    return PendingGpsPointsCompanion(
      id: Value(id),
      tripId:
          tripId == null && nullToAbsent ? const Value.absent() : Value(tripId),
      lat: Value(lat),
      lng: Value(lng),
      speedKph: speedKph == null && nullToAbsent
          ? const Value.absent()
          : Value(speedKph),
      headingDeg: headingDeg == null && nullToAbsent
          ? const Value.absent()
          : Value(headingDeg),
      accuracyM: accuracyM == null && nullToAbsent
          ? const Value.absent()
          : Value(accuracyM),
      recordedAt: Value(recordedAt),
      synced: Value(synced),
    );
  }

  factory PendingGpsPoint.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingGpsPoint(
      id: serializer.fromJson<String>(json['id']),
      tripId: serializer.fromJson<int?>(json['tripId']),
      lat: serializer.fromJson<double>(json['lat']),
      lng: serializer.fromJson<double>(json['lng']),
      speedKph: serializer.fromJson<double?>(json['speedKph']),
      headingDeg: serializer.fromJson<double?>(json['headingDeg']),
      accuracyM: serializer.fromJson<double?>(json['accuracyM']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tripId': serializer.toJson<int?>(tripId),
      'lat': serializer.toJson<double>(lat),
      'lng': serializer.toJson<double>(lng),
      'speedKph': serializer.toJson<double?>(speedKph),
      'headingDeg': serializer.toJson<double?>(headingDeg),
      'accuracyM': serializer.toJson<double?>(accuracyM),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  PendingGpsPoint copyWith(
          {String? id,
          Value<int?> tripId = const Value.absent(),
          double? lat,
          double? lng,
          Value<double?> speedKph = const Value.absent(),
          Value<double?> headingDeg = const Value.absent(),
          Value<double?> accuracyM = const Value.absent(),
          DateTime? recordedAt,
          bool? synced}) =>
      PendingGpsPoint(
        id: id ?? this.id,
        tripId: tripId.present ? tripId.value : this.tripId,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        speedKph: speedKph.present ? speedKph.value : this.speedKph,
        headingDeg: headingDeg.present ? headingDeg.value : this.headingDeg,
        accuracyM: accuracyM.present ? accuracyM.value : this.accuracyM,
        recordedAt: recordedAt ?? this.recordedAt,
        synced: synced ?? this.synced,
      );
  PendingGpsPoint copyWithCompanion(PendingGpsPointsCompanion data) {
    return PendingGpsPoint(
      id: data.id.present ? data.id.value : this.id,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      speedKph: data.speedKph.present ? data.speedKph.value : this.speedKph,
      headingDeg:
          data.headingDeg.present ? data.headingDeg.value : this.headingDeg,
      accuracyM: data.accuracyM.present ? data.accuracyM.value : this.accuracyM,
      recordedAt:
          data.recordedAt.present ? data.recordedAt.value : this.recordedAt,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingGpsPoint(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('speedKph: $speedKph, ')
          ..write('headingDeg: $headingDeg, ')
          ..write('accuracyM: $accuracyM, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tripId, lat, lng, speedKph, headingDeg,
      accuracyM, recordedAt, synced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingGpsPoint &&
          other.id == this.id &&
          other.tripId == this.tripId &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.speedKph == this.speedKph &&
          other.headingDeg == this.headingDeg &&
          other.accuracyM == this.accuracyM &&
          other.recordedAt == this.recordedAt &&
          other.synced == this.synced);
}

class PendingGpsPointsCompanion extends UpdateCompanion<PendingGpsPoint> {
  final Value<String> id;
  final Value<int?> tripId;
  final Value<double> lat;
  final Value<double> lng;
  final Value<double?> speedKph;
  final Value<double?> headingDeg;
  final Value<double?> accuracyM;
  final Value<DateTime> recordedAt;
  final Value<bool> synced;
  final Value<int> rowid;
  const PendingGpsPointsCompanion({
    this.id = const Value.absent(),
    this.tripId = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.speedKph = const Value.absent(),
    this.headingDeg = const Value.absent(),
    this.accuracyM = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingGpsPointsCompanion.insert({
    required String id,
    this.tripId = const Value.absent(),
    required double lat,
    required double lng,
    this.speedKph = const Value.absent(),
    this.headingDeg = const Value.absent(),
    this.accuracyM = const Value.absent(),
    required DateTime recordedAt,
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        lat = Value(lat),
        lng = Value(lng),
        recordedAt = Value(recordedAt);
  static Insertable<PendingGpsPoint> custom({
    Expression<String>? id,
    Expression<int>? tripId,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<double>? speedKph,
    Expression<double>? headingDeg,
    Expression<double>? accuracyM,
    Expression<DateTime>? recordedAt,
    Expression<bool>? synced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tripId != null) 'trip_id': tripId,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (speedKph != null) 'speed_kph': speedKph,
      if (headingDeg != null) 'heading_deg': headingDeg,
      if (accuracyM != null) 'accuracy_m': accuracyM,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (synced != null) 'synced': synced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingGpsPointsCompanion copyWith(
      {Value<String>? id,
      Value<int?>? tripId,
      Value<double>? lat,
      Value<double>? lng,
      Value<double?>? speedKph,
      Value<double?>? headingDeg,
      Value<double?>? accuracyM,
      Value<DateTime>? recordedAt,
      Value<bool>? synced,
      Value<int>? rowid}) {
    return PendingGpsPointsCompanion(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      speedKph: speedKph ?? this.speedKph,
      headingDeg: headingDeg ?? this.headingDeg,
      accuracyM: accuracyM ?? this.accuracyM,
      recordedAt: recordedAt ?? this.recordedAt,
      synced: synced ?? this.synced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<int>(tripId.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (speedKph.present) {
      map['speed_kph'] = Variable<double>(speedKph.value);
    }
    if (headingDeg.present) {
      map['heading_deg'] = Variable<double>(headingDeg.value);
    }
    if (accuracyM.present) {
      map['accuracy_m'] = Variable<double>(accuracyM.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingGpsPointsCompanion(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('speedKph: $speedKph, ')
          ..write('headingDeg: $headingDeg, ')
          ..write('accuracyM: $accuracyM, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('synced: $synced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedTripsTable extends CachedTrips
    with TableInfo<$CachedTripsTable, CachedTrip> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedTripsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<int> tripId = GeneratedColumn<int>(
      'trip_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _tripJsonMeta =
      const VerificationMeta('tripJson');
  @override
  late final GeneratedColumn<String> tripJson = GeneratedColumn<String>(
      'trip_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cachedAtMeta =
      const VerificationMeta('cachedAt');
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
      'cached_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [tripId, tripJson, cachedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_trips';
  @override
  VerificationContext validateIntegrity(Insertable<CachedTrip> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('trip_id')) {
      context.handle(_tripIdMeta,
          tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta));
    }
    if (data.containsKey('trip_json')) {
      context.handle(_tripJsonMeta,
          tripJson.isAcceptableOrUnknown(data['trip_json']!, _tripJsonMeta));
    } else if (isInserting) {
      context.missing(_tripJsonMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(_cachedAtMeta,
          cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta));
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tripId};
  @override
  CachedTrip map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedTrip(
      tripId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}trip_id'])!,
      tripJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}trip_json'])!,
      cachedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}cached_at'])!,
    );
  }

  @override
  $CachedTripsTable createAlias(String alias) {
    return $CachedTripsTable(attachedDatabase, alias);
  }
}

class CachedTrip extends DataClass implements Insertable<CachedTrip> {
  final int tripId;
  final String tripJson;
  final DateTime cachedAt;
  const CachedTrip(
      {required this.tripId, required this.tripJson, required this.cachedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['trip_id'] = Variable<int>(tripId);
    map['trip_json'] = Variable<String>(tripJson);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedTripsCompanion toCompanion(bool nullToAbsent) {
    return CachedTripsCompanion(
      tripId: Value(tripId),
      tripJson: Value(tripJson),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedTrip.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedTrip(
      tripId: serializer.fromJson<int>(json['tripId']),
      tripJson: serializer.fromJson<String>(json['tripJson']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tripId': serializer.toJson<int>(tripId),
      'tripJson': serializer.toJson<String>(tripJson),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedTrip copyWith({int? tripId, String? tripJson, DateTime? cachedAt}) =>
      CachedTrip(
        tripId: tripId ?? this.tripId,
        tripJson: tripJson ?? this.tripJson,
        cachedAt: cachedAt ?? this.cachedAt,
      );
  CachedTrip copyWithCompanion(CachedTripsCompanion data) {
    return CachedTrip(
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      tripJson: data.tripJson.present ? data.tripJson.value : this.tripJson,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedTrip(')
          ..write('tripId: $tripId, ')
          ..write('tripJson: $tripJson, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tripId, tripJson, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedTrip &&
          other.tripId == this.tripId &&
          other.tripJson == this.tripJson &&
          other.cachedAt == this.cachedAt);
}

class CachedTripsCompanion extends UpdateCompanion<CachedTrip> {
  final Value<int> tripId;
  final Value<String> tripJson;
  final Value<DateTime> cachedAt;
  const CachedTripsCompanion({
    this.tripId = const Value.absent(),
    this.tripJson = const Value.absent(),
    this.cachedAt = const Value.absent(),
  });
  CachedTripsCompanion.insert({
    this.tripId = const Value.absent(),
    required String tripJson,
    required DateTime cachedAt,
  })  : tripJson = Value(tripJson),
        cachedAt = Value(cachedAt);
  static Insertable<CachedTrip> custom({
    Expression<int>? tripId,
    Expression<String>? tripJson,
    Expression<DateTime>? cachedAt,
  }) {
    return RawValuesInsertable({
      if (tripId != null) 'trip_id': tripId,
      if (tripJson != null) 'trip_json': tripJson,
      if (cachedAt != null) 'cached_at': cachedAt,
    });
  }

  CachedTripsCompanion copyWith(
      {Value<int>? tripId,
      Value<String>? tripJson,
      Value<DateTime>? cachedAt}) {
    return CachedTripsCompanion(
      tripId: tripId ?? this.tripId,
      tripJson: tripJson ?? this.tripJson,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tripId.present) {
      map['trip_id'] = Variable<int>(tripId.value);
    }
    if (tripJson.present) {
      map['trip_json'] = Variable<String>(tripJson.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedTripsCompanion(')
          ..write('tripId: $tripId, ')
          ..write('tripJson: $tripJson, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PendingActionsTable pendingActions = $PendingActionsTable(this);
  late final $PendingGpsPointsTable pendingGpsPoints =
      $PendingGpsPointsTable(this);
  late final $CachedTripsTable cachedTrips = $CachedTripsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [pendingActions, pendingGpsPoints, cachedTrips];
}

typedef $$PendingActionsTableCreateCompanionBuilder = PendingActionsCompanion
    Function({
  required String id,
  required String actionType,
  Value<int?> tripId,
  Value<int?> stopId,
  required String payloadJson,
  required DateTime createdAt,
  Value<String> status,
  Value<int> retryCount,
  Value<String?> lastError,
  Value<int> rowid,
});
typedef $$PendingActionsTableUpdateCompanionBuilder = PendingActionsCompanion
    Function({
  Value<String> id,
  Value<String> actionType,
  Value<int?> tripId,
  Value<int?> stopId,
  Value<String> payloadJson,
  Value<DateTime> createdAt,
  Value<String> status,
  Value<int> retryCount,
  Value<String?> lastError,
  Value<int> rowid,
});

class $$PendingActionsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingActionsTable> {
  $$PendingActionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get actionType => $composableBuilder(
      column: $table.actionType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tripId => $composableBuilder(
      column: $table.tripId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get stopId => $composableBuilder(
      column: $table.stopId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));
}

class $$PendingActionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingActionsTable> {
  $$PendingActionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get actionType => $composableBuilder(
      column: $table.actionType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tripId => $composableBuilder(
      column: $table.tripId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get stopId => $composableBuilder(
      column: $table.stopId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));
}

class $$PendingActionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingActionsTable> {
  $$PendingActionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get actionType => $composableBuilder(
      column: $table.actionType, builder: (column) => column);

  GeneratedColumn<int> get tripId =>
      $composableBuilder(column: $table.tripId, builder: (column) => column);

  GeneratedColumn<int> get stopId =>
      $composableBuilder(column: $table.stopId, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$PendingActionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PendingActionsTable,
    PendingAction,
    $$PendingActionsTableFilterComposer,
    $$PendingActionsTableOrderingComposer,
    $$PendingActionsTableAnnotationComposer,
    $$PendingActionsTableCreateCompanionBuilder,
    $$PendingActionsTableUpdateCompanionBuilder,
    (
      PendingAction,
      BaseReferences<_$AppDatabase, $PendingActionsTable, PendingAction>
    ),
    PendingAction,
    PrefetchHooks Function()> {
  $$PendingActionsTableTableManager(
      _$AppDatabase db, $PendingActionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingActionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingActionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingActionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> actionType = const Value.absent(),
            Value<int?> tripId = const Value.absent(),
            Value<int?> stopId = const Value.absent(),
            Value<String> payloadJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PendingActionsCompanion(
            id: id,
            actionType: actionType,
            tripId: tripId,
            stopId: stopId,
            payloadJson: payloadJson,
            createdAt: createdAt,
            status: status,
            retryCount: retryCount,
            lastError: lastError,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String actionType,
            Value<int?> tripId = const Value.absent(),
            Value<int?> stopId = const Value.absent(),
            required String payloadJson,
            required DateTime createdAt,
            Value<String> status = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PendingActionsCompanion.insert(
            id: id,
            actionType: actionType,
            tripId: tripId,
            stopId: stopId,
            payloadJson: payloadJson,
            createdAt: createdAt,
            status: status,
            retryCount: retryCount,
            lastError: lastError,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PendingActionsTable, PendingAction>(table),
                    BaseReferences<_$AppDatabase, $PendingActionsTable,
                        PendingAction>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PendingActionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PendingActionsTable,
    PendingAction,
    $$PendingActionsTableFilterComposer,
    $$PendingActionsTableOrderingComposer,
    $$PendingActionsTableAnnotationComposer,
    $$PendingActionsTableCreateCompanionBuilder,
    $$PendingActionsTableUpdateCompanionBuilder,
    (
      PendingAction,
      BaseReferences<_$AppDatabase, $PendingActionsTable, PendingAction>
    ),
    PendingAction,
    PrefetchHooks Function()>;
typedef $$PendingGpsPointsTableCreateCompanionBuilder
    = PendingGpsPointsCompanion Function({
  required String id,
  Value<int?> tripId,
  required double lat,
  required double lng,
  Value<double?> speedKph,
  Value<double?> headingDeg,
  Value<double?> accuracyM,
  required DateTime recordedAt,
  Value<bool> synced,
  Value<int> rowid,
});
typedef $$PendingGpsPointsTableUpdateCompanionBuilder
    = PendingGpsPointsCompanion Function({
  Value<String> id,
  Value<int?> tripId,
  Value<double> lat,
  Value<double> lng,
  Value<double?> speedKph,
  Value<double?> headingDeg,
  Value<double?> accuracyM,
  Value<DateTime> recordedAt,
  Value<bool> synced,
  Value<int> rowid,
});

class $$PendingGpsPointsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingGpsPointsTable> {
  $$PendingGpsPointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tripId => $composableBuilder(
      column: $table.tripId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lat => $composableBuilder(
      column: $table.lat, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lng => $composableBuilder(
      column: $table.lng, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get speedKph => $composableBuilder(
      column: $table.speedKph, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get headingDeg => $composableBuilder(
      column: $table.headingDeg, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get accuracyM => $composableBuilder(
      column: $table.accuracyM, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnFilters(column));
}

class $$PendingGpsPointsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingGpsPointsTable> {
  $$PendingGpsPointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tripId => $composableBuilder(
      column: $table.tripId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lat => $composableBuilder(
      column: $table.lat, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lng => $composableBuilder(
      column: $table.lng, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get speedKph => $composableBuilder(
      column: $table.speedKph, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get headingDeg => $composableBuilder(
      column: $table.headingDeg, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get accuracyM => $composableBuilder(
      column: $table.accuracyM, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnOrderings(column));
}

class $$PendingGpsPointsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingGpsPointsTable> {
  $$PendingGpsPointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get tripId =>
      $composableBuilder(column: $table.tripId, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<double> get speedKph =>
      $composableBuilder(column: $table.speedKph, builder: (column) => column);

  GeneratedColumn<double> get headingDeg => $composableBuilder(
      column: $table.headingDeg, builder: (column) => column);

  GeneratedColumn<double> get accuracyM =>
      $composableBuilder(column: $table.accuracyM, builder: (column) => column);

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$PendingGpsPointsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PendingGpsPointsTable,
    PendingGpsPoint,
    $$PendingGpsPointsTableFilterComposer,
    $$PendingGpsPointsTableOrderingComposer,
    $$PendingGpsPointsTableAnnotationComposer,
    $$PendingGpsPointsTableCreateCompanionBuilder,
    $$PendingGpsPointsTableUpdateCompanionBuilder,
    (
      PendingGpsPoint,
      BaseReferences<_$AppDatabase, $PendingGpsPointsTable, PendingGpsPoint>
    ),
    PendingGpsPoint,
    PrefetchHooks Function()> {
  $$PendingGpsPointsTableTableManager(
      _$AppDatabase db, $PendingGpsPointsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingGpsPointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingGpsPointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingGpsPointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<int?> tripId = const Value.absent(),
            Value<double> lat = const Value.absent(),
            Value<double> lng = const Value.absent(),
            Value<double?> speedKph = const Value.absent(),
            Value<double?> headingDeg = const Value.absent(),
            Value<double?> accuracyM = const Value.absent(),
            Value<DateTime> recordedAt = const Value.absent(),
            Value<bool> synced = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PendingGpsPointsCompanion(
            id: id,
            tripId: tripId,
            lat: lat,
            lng: lng,
            speedKph: speedKph,
            headingDeg: headingDeg,
            accuracyM: accuracyM,
            recordedAt: recordedAt,
            synced: synced,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<int?> tripId = const Value.absent(),
            required double lat,
            required double lng,
            Value<double?> speedKph = const Value.absent(),
            Value<double?> headingDeg = const Value.absent(),
            Value<double?> accuracyM = const Value.absent(),
            required DateTime recordedAt,
            Value<bool> synced = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PendingGpsPointsCompanion.insert(
            id: id,
            tripId: tripId,
            lat: lat,
            lng: lng,
            speedKph: speedKph,
            headingDeg: headingDeg,
            accuracyM: accuracyM,
            recordedAt: recordedAt,
            synced: synced,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PendingGpsPointsTable, PendingGpsPoint>(table),
                    BaseReferences<_$AppDatabase, $PendingGpsPointsTable,
                        PendingGpsPoint>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PendingGpsPointsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PendingGpsPointsTable,
    PendingGpsPoint,
    $$PendingGpsPointsTableFilterComposer,
    $$PendingGpsPointsTableOrderingComposer,
    $$PendingGpsPointsTableAnnotationComposer,
    $$PendingGpsPointsTableCreateCompanionBuilder,
    $$PendingGpsPointsTableUpdateCompanionBuilder,
    (
      PendingGpsPoint,
      BaseReferences<_$AppDatabase, $PendingGpsPointsTable, PendingGpsPoint>
    ),
    PendingGpsPoint,
    PrefetchHooks Function()>;
typedef $$CachedTripsTableCreateCompanionBuilder = CachedTripsCompanion
    Function({
  Value<int> tripId,
  required String tripJson,
  required DateTime cachedAt,
});
typedef $$CachedTripsTableUpdateCompanionBuilder = CachedTripsCompanion
    Function({
  Value<int> tripId,
  Value<String> tripJson,
  Value<DateTime> cachedAt,
});

class $$CachedTripsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedTripsTable> {
  $$CachedTripsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get tripId => $composableBuilder(
      column: $table.tripId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tripJson => $composableBuilder(
      column: $table.tripJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnFilters(column));
}

class $$CachedTripsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedTripsTable> {
  $$CachedTripsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get tripId => $composableBuilder(
      column: $table.tripId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tripJson => $composableBuilder(
      column: $table.tripJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnOrderings(column));
}

class $$CachedTripsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedTripsTable> {
  $$CachedTripsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get tripId =>
      $composableBuilder(column: $table.tripId, builder: (column) => column);

  GeneratedColumn<String> get tripJson =>
      $composableBuilder(column: $table.tripJson, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedTripsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedTripsTable,
    CachedTrip,
    $$CachedTripsTableFilterComposer,
    $$CachedTripsTableOrderingComposer,
    $$CachedTripsTableAnnotationComposer,
    $$CachedTripsTableCreateCompanionBuilder,
    $$CachedTripsTableUpdateCompanionBuilder,
    (CachedTrip, BaseReferences<_$AppDatabase, $CachedTripsTable, CachedTrip>),
    CachedTrip,
    PrefetchHooks Function()> {
  $$CachedTripsTableTableManager(_$AppDatabase db, $CachedTripsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedTripsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedTripsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedTripsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> tripId = const Value.absent(),
            Value<String> tripJson = const Value.absent(),
            Value<DateTime> cachedAt = const Value.absent(),
          }) =>
              CachedTripsCompanion(
            tripId: tripId,
            tripJson: tripJson,
            cachedAt: cachedAt,
          ),
          createCompanionCallback: ({
            Value<int> tripId = const Value.absent(),
            required String tripJson,
            required DateTime cachedAt,
          }) =>
              CachedTripsCompanion.insert(
            tripId: tripId,
            tripJson: tripJson,
            cachedAt: cachedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$CachedTripsTable, CachedTrip>(table),
                    BaseReferences<_$AppDatabase, $CachedTripsTable,
                        CachedTrip>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedTripsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CachedTripsTable,
    CachedTrip,
    $$CachedTripsTableFilterComposer,
    $$CachedTripsTableOrderingComposer,
    $$CachedTripsTableAnnotationComposer,
    $$CachedTripsTableCreateCompanionBuilder,
    $$CachedTripsTableUpdateCompanionBuilder,
    (CachedTrip, BaseReferences<_$AppDatabase, $CachedTripsTable, CachedTrip>),
    CachedTrip,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PendingActionsTableTableManager get pendingActions =>
      $$PendingActionsTableTableManager(_db, _db.pendingActions);
  $$PendingGpsPointsTableTableManager get pendingGpsPoints =>
      $$PendingGpsPointsTableTableManager(_db, _db.pendingGpsPoints);
  $$CachedTripsTableTableManager get cachedTrips =>
      $$CachedTripsTableTableManager(_db, _db.cachedTrips);
}
