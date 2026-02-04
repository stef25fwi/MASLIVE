// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_cache_service.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CachedGroupPositionAdapter extends TypeAdapter<CachedGroupPosition> {
  @override
  final int typeId = 101;

  @override
  CachedGroupPosition read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedGroupPosition()
      ..adminGroupId = fields[0] as String
      ..lat = fields[1] as double
      ..lng = fields[2] as double
      ..altitude = fields[3] as double?
      ..accuracy = fields[4] as int?
      ..timestamp = fields[5] as DateTime
      ..memberCount = fields[6] as int;
  }

  @override
  void write(BinaryWriter writer, CachedGroupPosition obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.adminGroupId)
      ..writeByte(1)
      ..write(obj.lat)
      ..writeByte(2)
      ..write(obj.lng)
      ..writeByte(3)
      ..write(obj.altitude)
      ..writeByte(4)
      ..write(obj.accuracy)
      ..writeByte(5)
      ..write(obj.timestamp)
      ..writeByte(6)
      ..write(obj.memberCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedGroupPositionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CachedGroupTrackerAdapter extends TypeAdapter<CachedGroupTracker> {
  @override
  final int typeId = 102;

  @override
  CachedGroupTracker read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedGroupTracker()
      ..uid = fields[0] as String
      ..adminGroupId = fields[1] as String
      ..displayName = fields[2] as String
      ..photoUrl = fields[3] as String?
      ..cachedAt = fields[4] as DateTime;
  }

  @override
  void write(BinaryWriter writer, CachedGroupTracker obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.uid)
      ..writeByte(1)
      ..write(obj.adminGroupId)
      ..writeByte(2)
      ..write(obj.displayName)
      ..writeByte(3)
      ..write(obj.photoUrl)
      ..writeByte(4)
      ..write(obj.cachedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedGroupTrackerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
