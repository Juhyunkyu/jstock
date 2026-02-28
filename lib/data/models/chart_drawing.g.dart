// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chart_drawing.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChartDrawingAdapter extends TypeAdapter<ChartDrawing> {
  @override
  final int typeId = 5;

  @override
  ChartDrawing read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChartDrawing(
      id: fields[0] as String,
      symbol: fields[1] as String,
      type: fields[2] as DrawingType,
      price: fields[3] as double,
      startDate: fields[4] as DateTime?,
      startPrice: fields[5] as double?,
      endDate: fields[6] as DateTime?,
      endPrice: fields[7] as double?,
      colorValue: fields[8] as int,
      createdAt: fields[9] as DateTime?,
      strokeWidth: fields[10] == null ? 1.0 : fields[10] as double,
      isLocked: fields[11] == null ? false : fields[11] as bool,
      lowerPrice: fields[12] == null ? 0.0 : fields[12] as double,
    );
  }

  @override
  void write(BinaryWriter writer, ChartDrawing obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.symbol)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.price)
      ..writeByte(4)
      ..write(obj.startDate)
      ..writeByte(5)
      ..write(obj.startPrice)
      ..writeByte(6)
      ..write(obj.endDate)
      ..writeByte(7)
      ..write(obj.endPrice)
      ..writeByte(8)
      ..write(obj.colorValue)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.strokeWidth)
      ..writeByte(11)
      ..write(obj.isLocked)
      ..writeByte(12)
      ..write(obj.lowerPrice);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartDrawingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DrawingTypeAdapter extends TypeAdapter<DrawingType> {
  @override
  final int typeId = 4;

  @override
  DrawingType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DrawingType.horizontalLine;
      case 1:
        return DrawingType.trendLine;
      case 2:
        return DrawingType.fibonacci;
      case 3:
        return DrawingType.supportResistanceZone;
      default:
        return DrawingType.horizontalLine;
    }
  }

  @override
  void write(BinaryWriter writer, DrawingType obj) {
    switch (obj) {
      case DrawingType.horizontalLine:
        writer.writeByte(0);
        break;
      case DrawingType.trendLine:
        writer.writeByte(1);
        break;
      case DrawingType.fibonacci:
        writer.writeByte(2);
        break;
      case DrawingType.supportResistanceZone:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DrawingTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
