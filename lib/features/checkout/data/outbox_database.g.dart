// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'outbox_database.dart';

// ignore_for_file: type=lint
class $PayOutboxTable extends PayOutbox
    with TableInfo<$PayOutboxTable, PayOutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PayOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientTxMeta =
      const VerificationMeta('clientTx');
  @override
  late final GeneratedColumn<String> clientTx = GeneratedColumn<String>(
      'client_tx', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _attemptsMeta =
      const VerificationMeta('attempts');
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
      'attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _ticketNoMeta =
      const VerificationMeta('ticketNo');
  @override
  late final GeneratedColumn<int> ticketNo = GeneratedColumn<int>(
      'ticket_no', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _resultJsonMeta =
      const VerificationMeta('resultJson');
  @override
  late final GeneratedColumn<String> resultJson = GeneratedColumn<String>(
      'result_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _errorMessageMeta =
      const VerificationMeta('errorMessage');
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
      'error_message', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        clientTx,
        payload,
        status,
        attempts,
        ticketNo,
        resultJson,
        errorMessage,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pay_outbox';
  @override
  VerificationContext validateIntegrity(Insertable<PayOutboxData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_tx')) {
      context.handle(_clientTxMeta,
          clientTx.isAcceptableOrUnknown(data['client_tx']!, _clientTxMeta));
    } else if (isInserting) {
      context.missing(_clientTxMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('attempts')) {
      context.handle(_attemptsMeta,
          attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta));
    }
    if (data.containsKey('ticket_no')) {
      context.handle(_ticketNoMeta,
          ticketNo.isAcceptableOrUnknown(data['ticket_no']!, _ticketNoMeta));
    }
    if (data.containsKey('result_json')) {
      context.handle(
          _resultJsonMeta,
          resultJson.isAcceptableOrUnknown(
              data['result_json']!, _resultJsonMeta));
    }
    if (data.containsKey('error_message')) {
      context.handle(
          _errorMessageMeta,
          errorMessage.isAcceptableOrUnknown(
              data['error_message']!, _errorMessageMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clientTx};
  @override
  PayOutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PayOutboxData(
      clientTx: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}client_tx'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      attempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempts'])!,
      ticketNo: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ticket_no']),
      resultJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}result_json']),
      errorMessage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}error_message']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $PayOutboxTable createAlias(String alias) {
    return $PayOutboxTable(attachedDatabase, alias);
  }
}

class PayOutboxData extends DataClass implements Insertable<PayOutboxData> {
  final String clientTx;
  final String payload;
  final String status;
  final int attempts;
  final int? ticketNo;
  final String? resultJson;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PayOutboxData(
      {required this.clientTx,
      required this.payload,
      required this.status,
      required this.attempts,
      this.ticketNo,
      this.resultJson,
      this.errorMessage,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_tx'] = Variable<String>(clientTx);
    map['payload'] = Variable<String>(payload);
    map['status'] = Variable<String>(status);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || ticketNo != null) {
      map['ticket_no'] = Variable<int>(ticketNo);
    }
    if (!nullToAbsent || resultJson != null) {
      map['result_json'] = Variable<String>(resultJson);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PayOutboxCompanion toCompanion(bool nullToAbsent) {
    return PayOutboxCompanion(
      clientTx: Value(clientTx),
      payload: Value(payload),
      status: Value(status),
      attempts: Value(attempts),
      ticketNo: ticketNo == null && nullToAbsent
          ? const Value.absent()
          : Value(ticketNo),
      resultJson: resultJson == null && nullToAbsent
          ? const Value.absent()
          : Value(resultJson),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PayOutboxData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PayOutboxData(
      clientTx: serializer.fromJson<String>(json['clientTx']),
      payload: serializer.fromJson<String>(json['payload']),
      status: serializer.fromJson<String>(json['status']),
      attempts: serializer.fromJson<int>(json['attempts']),
      ticketNo: serializer.fromJson<int?>(json['ticketNo']),
      resultJson: serializer.fromJson<String?>(json['resultJson']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientTx': serializer.toJson<String>(clientTx),
      'payload': serializer.toJson<String>(payload),
      'status': serializer.toJson<String>(status),
      'attempts': serializer.toJson<int>(attempts),
      'ticketNo': serializer.toJson<int?>(ticketNo),
      'resultJson': serializer.toJson<String?>(resultJson),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PayOutboxData copyWith(
          {String? clientTx,
          String? payload,
          String? status,
          int? attempts,
          Value<int?> ticketNo = const Value.absent(),
          Value<String?> resultJson = const Value.absent(),
          Value<String?> errorMessage = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      PayOutboxData(
        clientTx: clientTx ?? this.clientTx,
        payload: payload ?? this.payload,
        status: status ?? this.status,
        attempts: attempts ?? this.attempts,
        ticketNo: ticketNo.present ? ticketNo.value : this.ticketNo,
        resultJson: resultJson.present ? resultJson.value : this.resultJson,
        errorMessage:
            errorMessage.present ? errorMessage.value : this.errorMessage,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  PayOutboxData copyWithCompanion(PayOutboxCompanion data) {
    return PayOutboxData(
      clientTx: data.clientTx.present ? data.clientTx.value : this.clientTx,
      payload: data.payload.present ? data.payload.value : this.payload,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      ticketNo: data.ticketNo.present ? data.ticketNo.value : this.ticketNo,
      resultJson:
          data.resultJson.present ? data.resultJson.value : this.resultJson,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PayOutboxData(')
          ..write('clientTx: $clientTx, ')
          ..write('payload: $payload, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('ticketNo: $ticketNo, ')
          ..write('resultJson: $resultJson, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(clientTx, payload, status, attempts, ticketNo,
      resultJson, errorMessage, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PayOutboxData &&
          other.clientTx == this.clientTx &&
          other.payload == this.payload &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.ticketNo == this.ticketNo &&
          other.resultJson == this.resultJson &&
          other.errorMessage == this.errorMessage &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PayOutboxCompanion extends UpdateCompanion<PayOutboxData> {
  final Value<String> clientTx;
  final Value<String> payload;
  final Value<String> status;
  final Value<int> attempts;
  final Value<int?> ticketNo;
  final Value<String?> resultJson;
  final Value<String?> errorMessage;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PayOutboxCompanion({
    this.clientTx = const Value.absent(),
    this.payload = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.ticketNo = const Value.absent(),
    this.resultJson = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PayOutboxCompanion.insert({
    required String clientTx,
    required String payload,
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.ticketNo = const Value.absent(),
    this.resultJson = const Value.absent(),
    this.errorMessage = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : clientTx = Value(clientTx),
        payload = Value(payload),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<PayOutboxData> custom({
    Expression<String>? clientTx,
    Expression<String>? payload,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<int>? ticketNo,
    Expression<String>? resultJson,
    Expression<String>? errorMessage,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientTx != null) 'client_tx': clientTx,
      if (payload != null) 'payload': payload,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (ticketNo != null) 'ticket_no': ticketNo,
      if (resultJson != null) 'result_json': resultJson,
      if (errorMessage != null) 'error_message': errorMessage,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PayOutboxCompanion copyWith(
      {Value<String>? clientTx,
      Value<String>? payload,
      Value<String>? status,
      Value<int>? attempts,
      Value<int?>? ticketNo,
      Value<String?>? resultJson,
      Value<String?>? errorMessage,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return PayOutboxCompanion(
      clientTx: clientTx ?? this.clientTx,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      ticketNo: ticketNo ?? this.ticketNo,
      resultJson: resultJson ?? this.resultJson,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientTx.present) {
      map['client_tx'] = Variable<String>(clientTx.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (ticketNo.present) {
      map['ticket_no'] = Variable<int>(ticketNo.value);
    }
    if (resultJson.present) {
      map['result_json'] = Variable<String>(resultJson.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PayOutboxCompanion(')
          ..write('clientTx: $clientTx, ')
          ..write('payload: $payload, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('ticketNo: $ticketNo, ')
          ..write('resultJson: $resultJson, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$OutboxDatabase extends GeneratedDatabase {
  _$OutboxDatabase(QueryExecutor e) : super(e);
  $OutboxDatabaseManager get managers => $OutboxDatabaseManager(this);
  late final $PayOutboxTable payOutbox = $PayOutboxTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [payOutbox];
}

typedef $$PayOutboxTableCreateCompanionBuilder = PayOutboxCompanion Function({
  required String clientTx,
  required String payload,
  Value<String> status,
  Value<int> attempts,
  Value<int?> ticketNo,
  Value<String?> resultJson,
  Value<String?> errorMessage,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$PayOutboxTableUpdateCompanionBuilder = PayOutboxCompanion Function({
  Value<String> clientTx,
  Value<String> payload,
  Value<String> status,
  Value<int> attempts,
  Value<int?> ticketNo,
  Value<String?> resultJson,
  Value<String?> errorMessage,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$PayOutboxTableFilterComposer
    extends Composer<_$OutboxDatabase, $PayOutboxTable> {
  $$PayOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientTx => $composableBuilder(
      column: $table.clientTx, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ticketNo => $composableBuilder(
      column: $table.ticketNo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get resultJson => $composableBuilder(
      column: $table.resultJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$PayOutboxTableOrderingComposer
    extends Composer<_$OutboxDatabase, $PayOutboxTable> {
  $$PayOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientTx => $composableBuilder(
      column: $table.clientTx, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ticketNo => $composableBuilder(
      column: $table.ticketNo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get resultJson => $composableBuilder(
      column: $table.resultJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$PayOutboxTableAnnotationComposer
    extends Composer<_$OutboxDatabase, $PayOutboxTable> {
  $$PayOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientTx =>
      $composableBuilder(column: $table.clientTx, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<int> get ticketNo =>
      $composableBuilder(column: $table.ticketNo, builder: (column) => column);

  GeneratedColumn<String> get resultJson => $composableBuilder(
      column: $table.resultJson, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PayOutboxTableTableManager extends RootTableManager<
    _$OutboxDatabase,
    $PayOutboxTable,
    PayOutboxData,
    $$PayOutboxTableFilterComposer,
    $$PayOutboxTableOrderingComposer,
    $$PayOutboxTableAnnotationComposer,
    $$PayOutboxTableCreateCompanionBuilder,
    $$PayOutboxTableUpdateCompanionBuilder,
    (
      PayOutboxData,
      BaseReferences<_$OutboxDatabase, $PayOutboxTable, PayOutboxData>
    ),
    PayOutboxData,
    PrefetchHooks Function()> {
  $$PayOutboxTableTableManager(_$OutboxDatabase db, $PayOutboxTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PayOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PayOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PayOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientTx = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<int?> ticketNo = const Value.absent(),
            Value<String?> resultJson = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PayOutboxCompanion(
            clientTx: clientTx,
            payload: payload,
            status: status,
            attempts: attempts,
            ticketNo: ticketNo,
            resultJson: resultJson,
            errorMessage: errorMessage,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String clientTx,
            required String payload,
            Value<String> status = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<int?> ticketNo = const Value.absent(),
            Value<String?> resultJson = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              PayOutboxCompanion.insert(
            clientTx: clientTx,
            payload: payload,
            status: status,
            attempts: attempts,
            ticketNo: ticketNo,
            resultJson: resultJson,
            errorMessage: errorMessage,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PayOutboxTable, PayOutboxData>(table),
                    BaseReferences<_$OutboxDatabase, $PayOutboxTable,
                        PayOutboxData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PayOutboxTableProcessedTableManager = ProcessedTableManager<
    _$OutboxDatabase,
    $PayOutboxTable,
    PayOutboxData,
    $$PayOutboxTableFilterComposer,
    $$PayOutboxTableOrderingComposer,
    $$PayOutboxTableAnnotationComposer,
    $$PayOutboxTableCreateCompanionBuilder,
    $$PayOutboxTableUpdateCompanionBuilder,
    (
      PayOutboxData,
      BaseReferences<_$OutboxDatabase, $PayOutboxTable, PayOutboxData>
    ),
    PayOutboxData,
    PrefetchHooks Function()>;

class $OutboxDatabaseManager {
  final _$OutboxDatabase _db;
  $OutboxDatabaseManager(this._db);
  $$PayOutboxTableTableManager get payOutbox =>
      $$PayOutboxTableTableManager(_db, _db.payOutbox);
}
