import 'dart:convert';

import 'package:electricsql/src/util/common.dart';
import 'package:electricsql/src/util/sets.dart';
import 'package:electricsql/src/util/tablename.dart';
import 'package:electricsql/src/util/types.dart';
import 'package:equatable/equatable.dart';
import 'package:fixnum/fixnum.dart';

// format: UUID@timestamp_in_milliseconds
typedef Timestamp = String;
typedef Tag = String;

typedef ShadowKey = String;

enum OpType {
  delete,
  insert,
  update,
}

enum ChangesOpType {
  delete,
  upsert,
}

class OplogEntryChanges {
  final String namespace;
  final String tablename;
  final Map<String, Object> primaryKeyCols;
  ChangesOpType optype;
  final OplogColumnChanges changes;
  Tag? tag;
  List<Tag> clearTags;

  OplogEntryChanges({
    required this.namespace,
    required this.tablename,
    required this.primaryKeyCols,
    required this.optype,
    required this.changes,
    required this.tag,
    required this.clearTags,
  });
}

class OplogEntry with EquatableMixin {
  final String namespace;
  final String tablename;
  final String primaryKey; // json object
  final int rowid;
  final OpType optype;
  final String timestamp; // ISO string
  String? newRow; // json object if present
  String? oldRow; // json object if present
  String clearTags; // json object if present

  OplogEntry({
    required this.namespace,
    required this.tablename,
    required this.primaryKey,
    required this.rowid,
    required this.optype,
    required this.timestamp,
    required this.clearTags,
    this.newRow,
    this.oldRow,
  });

  @override
  String toString() {
    return '$optype $namespace.$tablename $primaryKey - $newRow';
  }

  @override
  List<Object?> get props => [
        namespace,
        tablename,
        primaryKey,
        rowid,
        optype,
        timestamp,
        newRow,
        oldRow,
        clearTags,
      ];
}

OpType changeTypeToOpType(DataChangeType opTypeStr) {
  switch (opTypeStr) {
    case DataChangeType.insert:
      return OpType.insert;
    case DataChangeType.update:
      return OpType.update;
    case DataChangeType.delete:
      return OpType.delete;
  }
}

DataChangeType opTypeToChangeType(OpType opType) {
  switch (opType) {
    case OpType.delete:
      return DataChangeType.delete;
    case OpType.insert:
      return DataChangeType.insert;
    case OpType.update:
      return DataChangeType.update;
  }
}

const shadowTagsDefault = '[]';

OpType opTypeStrToOpType(String str) {
  switch (str.toLowerCase()) {
    case 'delete':
      return OpType.delete;
    case 'update':
      return OpType.update;
    case 'insert':
      return OpType.insert;
  }

  assert(false, 'OpType $str not handled');
  return OpType.insert;
}

List<OplogEntry> fromTransaction(
  DataTransaction transaction,
  RelationsCache relations,
) {
  return transaction.changes.map((t) {
    final columnValues = t.record ?? t.oldRecord!;
    final pk = primaryKeyToStr(
      Map.fromEntries(
        relations[t.relation.table]!
            .columns
            .where((c) => c.primaryKey ?? false)
            .map((col) => MapEntry(col.name, columnValues[col.name]!)),
      ),
    );

    return OplogEntry(
      namespace: 'main', // TODO: how?
      tablename: t.relation.table,
      primaryKey: pk,
      rowid: -1, // Not required
      optype: changeTypeToOpType(t.type),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        transaction.commitTimestamp.toInt(),
      ).toISOStringUTC(), // TODO: check precision
      newRow: t.record == null ? null : json.encode(t.record),
      oldRow: t.oldRecord == null ? null : json.encode(t.oldRecord),
      clearTags: encodeTags(t.tags),
    );
  }).toList();
}

List<DataTransaction> toTransactions(
  List<OplogEntry> opLogEntries,
  RelationsCache relations,
) {
  if (opLogEntries.isEmpty) {
    return [];
  }

  Int64 toCommitTimestamp(String timestamp) {
    return Int64(DateTime.parse(timestamp).millisecondsSinceEpoch);
  }

  final init = DataTransaction(
    commitTimestamp: toCommitTimestamp(opLogEntries[0].timestamp),
    lsn: numberToBytes(opLogEntries[0].rowid),
    changes: [],
  );

  return opLogEntries.fold(
    [init],
    (acc, txn) {
      var currTxn = acc[acc.length - 1];

      final nextTs = toCommitTimestamp(txn.timestamp);
      if (nextTs != currTxn.commitTimestamp) {
        final nextTxn = DataTransaction(
          commitTimestamp: toCommitTimestamp(txn.timestamp),
          lsn: numberToBytes(txn.rowid),
          changes: [],
        );
        acc.add(nextTxn);
        currTxn = nextTxn;
      }

      final change = opLogEntryToChange(txn, relations);
      currTxn.changes.add(change);
      currTxn.lsn = numberToBytes(txn.rowid);
      return acc;
    },
  );
}

ShadowEntry newShadowEntry(OplogEntry oplogEntry) {
  return ShadowEntry(
    namespace: oplogEntry.namespace,
    tablename: oplogEntry.tablename,
    primaryKey: primaryKeyToStr(
      (json.decode(oplogEntry.primaryKey) as Map<String, dynamic>)
          .cast<String, Object>(),
    ),
    tags: shadowTagsDefault,
  );
}

// Convert a list of `OplogEntry`s into a nested `OplogTableChanges` map of
// `{tableName: {primaryKey: entryChanges}}` where the entryChanges has the
// most recent `optype` and column `value`` from all of the operations.
// Multiple OplogEntries that point to the same row will be merged to a
// single OpLogEntryChanges object.
OplogTableChanges localOperationsToTableChanges(
  List<OplogEntry> operations,
  Tag Function(DateTime timestamp) genTag,
) {
  final OplogTableChanges initialValue = {};

  return operations.fold(initialValue, (acc, entry) {
    final entryChanges =
        localEntryToChanges(entry, genTag(DateTime.parse(entry.timestamp)));

    // Sort for deterministic key generation.
    final primaryKeyStr = primaryKeyToStr(entryChanges.primaryKeyCols);
    final qualifiedTablename =
        QualifiedTablename(entryChanges.namespace, entryChanges.tablename);
    final tablenameStr = qualifiedTablename.toString();

    if (acc[tablenameStr] == null) {
      acc[tablenameStr] = {};
    }

    if (acc[tablenameStr]![primaryKeyStr] == null) {
      acc[tablenameStr]![primaryKeyStr] = OplogTableChange(
        timestamp: entry.timestamp,
        oplogEntryChanges: entryChanges,
      );
    } else {
      final oplogTableChange = acc[tablenameStr]![primaryKeyStr]!;
      final timestamp = oplogTableChange.timestamp;
      final OplogEntryChanges existing = oplogTableChange.oplogEntryChanges;

      existing.optype = entryChanges.optype;
      for (final entry in entryChanges.changes.entries) {
        final key = entry.key;
        final value = entry.value;
        existing.changes[key] = value;
      }
      if (entryChanges.optype == ChangesOpType.delete) {
        existing.tag = null;
      } else {
        existing.tag = genTag(DateTime.parse(entry.timestamp));
      }

      if (timestamp == entry.timestamp) {
        // within the same transaction overwirte
        existing.clearTags = entryChanges.clearTags;
      } else {
        existing.clearTags = union(entryChanges.clearTags, existing.clearTags);
      }
    }

    return acc;
  });
}

PendingChanges remoteOperationsToTableChanges(List<OplogEntry> operations) {
  final PendingChanges initialValue = {};

  return operations.fold<PendingChanges>(initialValue, (acc, entry) {
    final entryChanges = remoteEntryToChanges(entry);

    // Sort for deterministic key generation.
    final primaryKeyStr = primaryKeyToStr(entryChanges.primaryKeyCols);
    final qualifiedTablename =
        QualifiedTablename(entryChanges.namespace, entryChanges.tablename);
    final tablenameStr = qualifiedTablename.toString();

    if (acc[tablenameStr] == null) {
      acc[tablenameStr] = {};
    }
    if (acc[tablenameStr]![primaryKeyStr] == null) {
      acc[tablenameStr]![primaryKeyStr] = entryChanges;
    } else {
      final ShadowEntryChanges existing = acc[tablenameStr]![primaryKeyStr]!;
      existing.optype = entryChanges.optype;
      for (final entry in entryChanges.changes.entries) {
        existing.changes[entry.key] = entry.value;
        existing.fullRow[entry.key] = entry.value.value;
      }
    }

    return acc;
  });
}

class OplogTableChange {
  final Timestamp timestamp;
  final OplogEntryChanges oplogEntryChanges;

  OplogTableChange({
    required this.timestamp,
    required this.oplogEntryChanges,
  });
}

class OplogColumnChange with EquatableMixin {
  final SqlValue value;
  final int timestamp;

  OplogColumnChange(this.value, this.timestamp);

  @override
  List<Object?> get props => [value, timestamp];
}

typedef OplogColumnChanges = Map<String, OplogColumnChange>;

// First key qualifiedTablenameStr
// Second key primaryKey
typedef PendingChanges = Map<String, Map<String, ShadowEntryChanges>>;
typedef OplogTableChanges = Map<String, Map<String, OplogTableChange>>;

class ShadowEntry with EquatableMixin {
  final String namespace;
  final String tablename;
  final String primaryKey;
  String tags;

  ShadowEntry({
    required this.namespace,
    required this.tablename,
    required this.primaryKey,
    required this.tags,
  });

  @override
  List<Object?> get props =>
      [namespace, tablename, primaryKey, tags]; // json object
}

// Convert an `OplogEntry` to an `OplogEntryChanges` structure,
// parsing out the changed columns from the oldRow and the newRow.
OplogEntryChanges localEntryToChanges(OplogEntry entry, Tag tag) {
  final OplogEntryChanges result = OplogEntryChanges(
    namespace: entry.namespace,
    tablename: entry.tablename,
    primaryKeyCols: (json.decode(entry.primaryKey) as Map<String, dynamic>)
        .cast<String, Object>(),
    optype: entry.optype == OpType.delete
        ? ChangesOpType.delete
        : ChangesOpType.upsert,
    changes: {},
    tag: entry.optype == OpType.delete ? null : tag,
    clearTags: (json.decode(entry.clearTags) as List<dynamic>).cast<String>(),
  );

  final Row oldRow =
      entry.oldRow != null ? json.decode(entry.oldRow!) as Row : {};
  final Row newRow =
      entry.newRow != null ? json.decode(entry.newRow!) as Row : {};

  final timestamp = DateTime.parse(entry.timestamp).millisecondsSinceEpoch;

  for (final entry in newRow.entries) {
    final key = entry.key;
    final value = entry.value;
    if (!oldRow.containsKey(key) || oldRow[key] != value) {
      result.changes[key] = OplogColumnChange(value, timestamp);
    }
  }
  return result;
}

// Convert an `OplogEntry` to a `ShadowEntryChanges` structure,
// parsing out the changed columns from the oldRow and the newRow.
ShadowEntryChanges remoteEntryToChanges(OplogEntry entry) {
  final Row oldRow = _decodeRow(entry.oldRow);
  final Row newRow = _decodeRow(entry.newRow);

  final result = ShadowEntryChanges(
    namespace: entry.namespace,
    tablename: entry.tablename,
    primaryKeyCols: (json.decode(entry.primaryKey) as Map<String, dynamic>)
        .cast<String, Object>(),
    optype: entry.optype == OpType.delete
        ? ChangesOpType.delete
        : ChangesOpType.upsert,
    changes: {},
    // if it is a delete, then `newRow` is empty so the full row is the old row
    fullRow: entry.optype == OpType.delete ? oldRow : newRow,
    tags: decodeTags(entry.clearTags),
  );

  final timestamp = DateTime.parse(entry.timestamp).millisecondsSinceEpoch;

  for (final entry in newRow.entries) {
    if (!oldRow.containsKey(entry.key) || oldRow[entry.key] != entry.value) {
      result.changes[entry.key] = OplogColumnChange(entry.value, timestamp);
    }
  }

  return result;
}

Row _decodeRow(String? row) {
  if (row == null) {
    return {};
  }

  final decoded = json.decode(row) as Row?;

  return decoded ?? {};
}

class ShadowEntryChanges with EquatableMixin {
  final String namespace;
  final String tablename;
  final Map<String, Object> primaryKeyCols;
  ChangesOpType optype;
  OplogColumnChanges changes;
  Row fullRow;
  List<Tag> tags;

  ShadowEntryChanges({
    required this.namespace,
    required this.tablename,
    required this.primaryKeyCols,
    required this.optype,
    required this.changes,
    required this.fullRow,
    required this.tags,
  });

  @override
  List<Object?> get props =>
      [namespace, tablename, primaryKeyCols, optype, changes, fullRow, tags];
}

/// Convert a primary key to a string the same way our triggers do when generating oplog entries.
///
/// Takes the object that contains the primary key and serializes it to JSON in a non-prettified
/// way with column sorting.
///
/// @param primaryKeyObj object representing all columns of a primary key
/// @returns a stringified JSON with stable sorting on column names
String primaryKeyToStr(Map<String, Object> primaryKeyObj) {
  final keys = primaryKeyObj.keys.toList()..sort();
  if (keys.isEmpty) return '{}';

  final jsonStr = StringBuffer('{');
  for (var i = 0; i < keys.length; i++) {
    final key = keys[i];
    jsonStr.write(json.encode(key));
    jsonStr.write(':');
    jsonStr.write(json.encode(primaryKeyObj[key]));

    if (i < keys.length - 1) {
      jsonStr.write(',');
    }
  }

  jsonStr.write('}');
  return jsonStr.toString();
}

ShadowKey getShadowPrimaryKey(
  Object oplogEntry,
) {
  if (oplogEntry is OplogEntry) {
    return oplogEntry.primaryKey;
  } else if (oplogEntry is OplogEntryChanges) {
    return primaryKeyToStr(oplogEntry.primaryKeyCols);
  } else if (oplogEntry is ShadowEntryChanges) {
    return primaryKeyToStr(oplogEntry.primaryKeyCols);
  } else {
    throw StateError('Unknown class');
  }
}

Tag generateTag(String instanceId, DateTime timestamp) {
  final milliseconds = timestamp.millisecondsSinceEpoch;
  return '$instanceId@$milliseconds';
}

String encodeTags(List<Tag> tags) {
  return json.encode(tags);
}

List<Tag> decodeTags(String tags) {
  return (json.decode(tags) as List<dynamic>).cast<Tag>();
}

DataChange opLogEntryToChange(OplogEntry entry, RelationsCache relations) {
  Map<String, Object?>? record;
  Map<String, Object?>? oldRecord;
  if (entry.newRow != null) {
    record = json.decode(entry.newRow!) as Map<String, Object?>;
  }

  if (entry.oldRow != null) {
    oldRecord = json.decode(entry.oldRow!) as Map<String, Object?>;
  }

  final relation = relations[entry.tablename];

  if (relation == null) {
    throw Exception('Could not find relation for ${entry.tablename}');
  }

  return DataChange(
    type: opTypeToChangeType(entry.optype),
    relation: relation,
    record: record,
    oldRecord: oldRecord,
    tags: decodeTags(entry.clearTags),
  );
}
