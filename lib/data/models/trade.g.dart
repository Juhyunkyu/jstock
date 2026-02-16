// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trade.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TradeAdapter extends TypeAdapter<Trade> {
  @override
  final int typeId = 2;

  @override
  Trade read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Trade(
      id: fields[0] as String,
      cycleId: fields[1] as String,
      ticker: fields[2] as String,
      date: fields[3] as DateTime,
      action: fields[4] as TradeAction,
      price: fields[5] as double,
      shares: fields[6] as double,
      recommendedAmount: fields[7] as double,
      actualAmount: fields[8] as double?,
      isExecuted: fields[9] as bool,
      lossRate: fields[10] as double,
      returnRate: fields[11] as double,
      note: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Trade obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.cycleId)
      ..writeByte(2)
      ..write(obj.ticker)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.action)
      ..writeByte(5)
      ..write(obj.price)
      ..writeByte(6)
      ..write(obj.shares)
      ..writeByte(7)
      ..write(obj.recommendedAmount)
      ..writeByte(8)
      ..write(obj.actualAmount)
      ..writeByte(9)
      ..write(obj.isExecuted)
      ..writeByte(10)
      ..write(obj.lossRate)
      ..writeByte(11)
      ..write(obj.returnRate)
      ..writeByte(12)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TradeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TradeActionAdapter extends TypeAdapter<TradeAction> {
  @override
  final int typeId = 11;

  @override
  TradeAction read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TradeAction.initialBuy;
      case 1:
        return TradeAction.weightedBuy;
      case 2:
        return TradeAction.panicBuy;
      case 3:
        return TradeAction.takeProfit;
      default:
        return TradeAction.initialBuy;
    }
  }

  @override
  void write(BinaryWriter writer, TradeAction obj) {
    switch (obj) {
      case TradeAction.initialBuy:
        writer.writeByte(0);
        break;
      case TradeAction.weightedBuy:
        writer.writeByte(1);
        break;
      case TradeAction.panicBuy:
        writer.writeByte(2);
        break;
      case TradeAction.takeProfit:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TradeActionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
