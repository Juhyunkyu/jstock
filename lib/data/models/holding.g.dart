// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'holding.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HoldingAdapter extends TypeAdapter<Holding> {
  @override
  final int typeId = 12;

  @override
  Holding read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Holding(
      id: fields[0] as String,
      ticker: fields[1] as String,
      name: fields[2] as String,
      exchangeRate: fields[8] as double,
      startDate: fields[6] as DateTime?,
      notes: fields[9] as String?,
      isArchived: fields[10] as bool?,
    )
      ..totalShares = fields[3] as double
      ..averagePrice = fields[4] as double
      ..totalInvestedAmount = fields[5] as double
      ..updatedAt = fields[7] as DateTime;
  }

  @override
  void write(BinaryWriter writer, Holding obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.ticker)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.totalShares)
      ..writeByte(4)
      ..write(obj.averagePrice)
      ..writeByte(5)
      ..write(obj.totalInvestedAmount)
      ..writeByte(6)
      ..write(obj.startDate)
      ..writeByte(7)
      ..write(obj.updatedAt)
      ..writeByte(8)
      ..write(obj.exchangeRate)
      ..writeByte(9)
      ..write(obj.notes)
      ..writeByte(10)
      ..write(obj.isArchived);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HoldingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
