// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rsi_watch_point.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RsiWatchPointAdapter extends TypeAdapter<RsiWatchPoint> {
  @override
  final int typeId = 27;

  @override
  RsiWatchPoint read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RsiWatchPoint(
      id: fields[0] as String,
      ticker: fields[1] as String,
      mode: fields[2] as int,
      watchPrice: fields[3] as double,
      watchRsi: fields[4] as double,
      watchDate: fields[5] as DateTime,
      interval: fields[6] as String,
      createdAt: fields[7] as DateTime?,
      isActive: fields[8] as bool? ?? true,
      triggeredRsi: fields[9] as double?,
      triggeredPrice: fields[10] as double?,
      triggeredAt: fields[11] as DateTime?,
      rsiPeriod: fields[12] as int? ?? 14,
    );
  }

  @override
  void write(BinaryWriter writer, RsiWatchPoint obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.ticker)
      ..writeByte(2)
      ..write(obj.mode)
      ..writeByte(3)
      ..write(obj.watchPrice)
      ..writeByte(4)
      ..write(obj.watchRsi)
      ..writeByte(5)
      ..write(obj.watchDate)
      ..writeByte(6)
      ..write(obj.interval)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.isActive)
      ..writeByte(9)
      ..write(obj.triggeredRsi)
      ..writeByte(10)
      ..write(obj.triggeredPrice)
      ..writeByte(11)
      ..write(obj.triggeredAt)
      ..writeByte(12)
      ..write(obj.rsiPeriod);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RsiWatchPointAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
