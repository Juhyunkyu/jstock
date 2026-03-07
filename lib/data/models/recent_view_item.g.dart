// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recent_view_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecentViewItemAdapter extends TypeAdapter<RecentViewItem> {
  @override
  final int typeId = 23;

  @override
  RecentViewItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecentViewItem(
      ticker: fields[0] as String,
      name: fields[1] as String,
      exchange: fields[2] as String,
      type: fields[3] as String,
      viewedAt: fields[4] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, RecentViewItem obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.ticker)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.exchange)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.viewedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecentViewItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
