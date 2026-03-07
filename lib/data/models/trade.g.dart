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
      action: fields[2] as TradeAction,
      signal: fields[3] as TradeSignal,
      price: fields[4] as double,
      shares: fields[5] as double,
      amountKrw: fields[6] as double,
      exchangeRate: fields[7] as double,
      tradedAt: fields[8] as DateTime?,
      memo: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Trade obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.cycleId)
      ..writeByte(2)
      ..write(obj.action)
      ..writeByte(3)
      ..write(obj.signal)
      ..writeByte(4)
      ..write(obj.price)
      ..writeByte(5)
      ..write(obj.shares)
      ..writeByte(6)
      ..write(obj.amountKrw)
      ..writeByte(7)
      ..write(obj.exchangeRate)
      ..writeByte(8)
      ..write(obj.tradedAt)
      ..writeByte(9)
      ..write(obj.memo);
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

class TradeSignalAdapter extends TypeAdapter<TradeSignal> {
  @override
  final int typeId = 21;

  @override
  TradeSignal read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TradeSignal.initial;
      case 1:
        return TradeSignal.weightedBuy;
      case 2:
        return TradeSignal.panicBuy;
      case 3:
        return TradeSignal.cashSecure;
      case 4:
        return TradeSignal.takeProfit;
      case 5:
        return TradeSignal.locA;
      case 6:
        return TradeSignal.locB;
      case 7:
        return TradeSignal.locAB;
      case 8:
        return TradeSignal.manual;
      case 9:
        return TradeSignal.hold;
      default:
        return TradeSignal.initial;
    }
  }

  @override
  void write(BinaryWriter writer, TradeSignal obj) {
    switch (obj) {
      case TradeSignal.initial:
        writer.writeByte(0);
        break;
      case TradeSignal.weightedBuy:
        writer.writeByte(1);
        break;
      case TradeSignal.panicBuy:
        writer.writeByte(2);
        break;
      case TradeSignal.cashSecure:
        writer.writeByte(3);
        break;
      case TradeSignal.takeProfit:
        writer.writeByte(4);
        break;
      case TradeSignal.locA:
        writer.writeByte(5);
        break;
      case TradeSignal.locB:
        writer.writeByte(6);
        break;
      case TradeSignal.locAB:
        writer.writeByte(7);
        break;
      case TradeSignal.manual:
        writer.writeByte(8);
        break;
      case TradeSignal.hold:
        writer.writeByte(9);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TradeSignalAdapter &&
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
        return TradeAction.buy;
      case 1:
        return TradeAction.sell;
      default:
        return TradeAction.buy;
    }
  }

  @override
  void write(BinaryWriter writer, TradeAction obj) {
    switch (obj) {
      case TradeAction.buy:
        writer.writeByte(0);
        break;
      case TradeAction.sell:
        writer.writeByte(1);
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
