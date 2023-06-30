//
//  Generated code. Do not modify.
//  source: proto/satellite.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class SatAuthHeader extends $pb.ProtobufEnum {
  static const SatAuthHeader UNSPECIFIED =
      SatAuthHeader._(0, _omitEnumNames ? '' : 'UNSPECIFIED');
  static const SatAuthHeader PROTO_VERSION =
      SatAuthHeader._(1, _omitEnumNames ? '' : 'PROTO_VERSION');
  static const SatAuthHeader SCHEMA_VERSION =
      SatAuthHeader._(2, _omitEnumNames ? '' : 'SCHEMA_VERSION');

  static const $core.List<SatAuthHeader> values = <SatAuthHeader>[
    UNSPECIFIED,
    PROTO_VERSION,
    SCHEMA_VERSION,
  ];

  static final $core.Map<$core.int, SatAuthHeader> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static SatAuthHeader? valueOf($core.int value) => _byValue[value];

  const SatAuthHeader._($core.int v, $core.String n) : super(v, n);
}

class SatErrorResp_ErrorCode extends $pb.ProtobufEnum {
  static const SatErrorResp_ErrorCode INTERNAL =
      SatErrorResp_ErrorCode._(0, _omitEnumNames ? '' : 'INTERNAL');
  static const SatErrorResp_ErrorCode AUTH_REQUIRED =
      SatErrorResp_ErrorCode._(1, _omitEnumNames ? '' : 'AUTH_REQUIRED');
  static const SatErrorResp_ErrorCode AUTH_FAILED =
      SatErrorResp_ErrorCode._(2, _omitEnumNames ? '' : 'AUTH_FAILED');
  static const SatErrorResp_ErrorCode REPLICATION_FAILED =
      SatErrorResp_ErrorCode._(3, _omitEnumNames ? '' : 'REPLICATION_FAILED');
  static const SatErrorResp_ErrorCode INVALID_REQUEST =
      SatErrorResp_ErrorCode._(4, _omitEnumNames ? '' : 'INVALID_REQUEST');
  static const SatErrorResp_ErrorCode PROTO_VSN_MISSMATCH =
      SatErrorResp_ErrorCode._(5, _omitEnumNames ? '' : 'PROTO_VSN_MISSMATCH');
  static const SatErrorResp_ErrorCode SCHEMA_VSN_MISSMATCH =
      SatErrorResp_ErrorCode._(6, _omitEnumNames ? '' : 'SCHEMA_VSN_MISSMATCH');

  static const $core.List<SatErrorResp_ErrorCode> values =
      <SatErrorResp_ErrorCode>[
    INTERNAL,
    AUTH_REQUIRED,
    AUTH_FAILED,
    REPLICATION_FAILED,
    INVALID_REQUEST,
    PROTO_VSN_MISSMATCH,
    SCHEMA_VSN_MISSMATCH,
  ];

  static final $core.Map<$core.int, SatErrorResp_ErrorCode> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static SatErrorResp_ErrorCode? valueOf($core.int value) => _byValue[value];

  const SatErrorResp_ErrorCode._($core.int v, $core.String n) : super(v, n);
}

class SatInStartReplicationReq_Option extends $pb.ProtobufEnum {
  static const SatInStartReplicationReq_Option NONE =
      SatInStartReplicationReq_Option._(0, _omitEnumNames ? '' : 'NONE');
  static const SatInStartReplicationReq_Option LAST_ACKNOWLEDGED =
      SatInStartReplicationReq_Option._(
          1, _omitEnumNames ? '' : 'LAST_ACKNOWLEDGED');
  static const SatInStartReplicationReq_Option SYNC_MODE =
      SatInStartReplicationReq_Option._(2, _omitEnumNames ? '' : 'SYNC_MODE');
  static const SatInStartReplicationReq_Option FIRST_LSN =
      SatInStartReplicationReq_Option._(3, _omitEnumNames ? '' : 'FIRST_LSN');
  static const SatInStartReplicationReq_Option LAST_LSN =
      SatInStartReplicationReq_Option._(4, _omitEnumNames ? '' : 'LAST_LSN');

  static const $core.List<SatInStartReplicationReq_Option> values =
      <SatInStartReplicationReq_Option>[
    NONE,
    LAST_ACKNOWLEDGED,
    SYNC_MODE,
    FIRST_LSN,
    LAST_LSN,
  ];

  static final $core.Map<$core.int, SatInStartReplicationReq_Option> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static SatInStartReplicationReq_Option? valueOf($core.int value) =>
      _byValue[value];

  const SatInStartReplicationReq_Option._($core.int v, $core.String n)
      : super(v, n);
}

class SatInStartReplicationResp_ReplicationError_Code extends $pb.ProtobufEnum {
  static const SatInStartReplicationResp_ReplicationError_Code
      CODE_UNSPECIFIED = SatInStartReplicationResp_ReplicationError_Code._(
          0, _omitEnumNames ? '' : 'CODE_UNSPECIFIED');
  static const SatInStartReplicationResp_ReplicationError_Code BEHIND_WINDOW =
      SatInStartReplicationResp_ReplicationError_Code._(
          1, _omitEnumNames ? '' : 'BEHIND_WINDOW');
  static const SatInStartReplicationResp_ReplicationError_Code
      INVALID_POSITION = SatInStartReplicationResp_ReplicationError_Code._(
          2, _omitEnumNames ? '' : 'INVALID_POSITION');
  static const SatInStartReplicationResp_ReplicationError_Code
      SUBSCRIPTION_NOT_FOUND =
      SatInStartReplicationResp_ReplicationError_Code._(
          3, _omitEnumNames ? '' : 'SUBSCRIPTION_NOT_FOUND');

  static const $core.List<SatInStartReplicationResp_ReplicationError_Code>
      values = <SatInStartReplicationResp_ReplicationError_Code>[
    CODE_UNSPECIFIED,
    BEHIND_WINDOW,
    INVALID_POSITION,
    SUBSCRIPTION_NOT_FOUND,
  ];

  static final $core
          .Map<$core.int, SatInStartReplicationResp_ReplicationError_Code>
      _byValue = $pb.ProtobufEnum.initByValue(values);
  static SatInStartReplicationResp_ReplicationError_Code? valueOf(
          $core.int value) =>
      _byValue[value];

  const SatInStartReplicationResp_ReplicationError_Code._(
      $core.int v, $core.String n)
      : super(v, n);
}

class SatRelation_RelationType extends $pb.ProtobufEnum {
  static const SatRelation_RelationType TABLE =
      SatRelation_RelationType._(0, _omitEnumNames ? '' : 'TABLE');
  static const SatRelation_RelationType INDEX =
      SatRelation_RelationType._(1, _omitEnumNames ? '' : 'INDEX');
  static const SatRelation_RelationType VIEW =
      SatRelation_RelationType._(2, _omitEnumNames ? '' : 'VIEW');
  static const SatRelation_RelationType TRIGGER =
      SatRelation_RelationType._(3, _omitEnumNames ? '' : 'TRIGGER');

  static const $core.List<SatRelation_RelationType> values =
      <SatRelation_RelationType>[
    TABLE,
    INDEX,
    VIEW,
    TRIGGER,
  ];

  static final $core.Map<$core.int, SatRelation_RelationType> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static SatRelation_RelationType? valueOf($core.int value) => _byValue[value];

  const SatRelation_RelationType._($core.int v, $core.String n) : super(v, n);
}

class SatOpMigrate_Type extends $pb.ProtobufEnum {
  static const SatOpMigrate_Type CREATE_TABLE =
      SatOpMigrate_Type._(0, _omitEnumNames ? '' : 'CREATE_TABLE');
  static const SatOpMigrate_Type CREATE_INDEX =
      SatOpMigrate_Type._(1, _omitEnumNames ? '' : 'CREATE_INDEX');
  static const SatOpMigrate_Type ALTER_ADD_COLUMN =
      SatOpMigrate_Type._(6, _omitEnumNames ? '' : 'ALTER_ADD_COLUMN');

  static const $core.List<SatOpMigrate_Type> values = <SatOpMigrate_Type>[
    CREATE_TABLE,
    CREATE_INDEX,
    ALTER_ADD_COLUMN,
  ];

  static final $core.Map<$core.int, SatOpMigrate_Type> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static SatOpMigrate_Type? valueOf($core.int value) => _byValue[value];

  const SatOpMigrate_Type._($core.int v, $core.String n) : super(v, n);
}

class SatSubsError_Code extends $pb.ProtobufEnum {
  static const SatSubsError_Code CODE_UNSPECIFIED =
      SatSubsError_Code._(0, _omitEnumNames ? '' : 'CODE_UNSPECIFIED');
  static const SatSubsError_Code SHAPE_REQUEST_ERROR =
      SatSubsError_Code._(1, _omitEnumNames ? '' : 'SHAPE_REQUEST_ERROR');

  static const $core.List<SatSubsError_Code> values = <SatSubsError_Code>[
    CODE_UNSPECIFIED,
    SHAPE_REQUEST_ERROR,
  ];

  static final $core.Map<$core.int, SatSubsError_Code> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static SatSubsError_Code? valueOf($core.int value) => _byValue[value];

  const SatSubsError_Code._($core.int v, $core.String n) : super(v, n);
}

class SatSubsError_ShapeReqError_Code extends $pb.ProtobufEnum {
  static const SatSubsError_ShapeReqError_Code CODE_UNSPECIFIED =
      SatSubsError_ShapeReqError_Code._(
          0, _omitEnumNames ? '' : 'CODE_UNSPECIFIED');
  static const SatSubsError_ShapeReqError_Code TABLE_NOT_FOUND =
      SatSubsError_ShapeReqError_Code._(
          1, _omitEnumNames ? '' : 'TABLE_NOT_FOUND');

  static const $core.List<SatSubsError_ShapeReqError_Code> values =
      <SatSubsError_ShapeReqError_Code>[
    CODE_UNSPECIFIED,
    TABLE_NOT_FOUND,
  ];

  static final $core.Map<$core.int, SatSubsError_ShapeReqError_Code> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static SatSubsError_ShapeReqError_Code? valueOf($core.int value) =>
      _byValue[value];

  const SatSubsError_ShapeReqError_Code._($core.int v, $core.String n)
      : super(v, n);
}

const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
