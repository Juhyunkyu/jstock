// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'holding_transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HoldingTransactionAdapter extends TypeAdapter<HoldingTransaction> {
  @override
  final int typeId = 13;

  @override
  HoldingTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HoldingTransaction(
      id: fields[0] as String,
      holdingId: fields[1] as String,
      ticker: fields[2] as String,
      date: fields[3] as DateTime,
      type: fields[4] as HoldingTransactionType,
      price: fields[5] as double,
      shares: fields[6] as double,
      amountKrw: fields[7] as double,
      exchangeRate: fields[8] as double,
      note: fields[9] as String?,
      realizedPnlKrw: fields[11] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, HoldingTransaction obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.holdingId)
      ..writeByte(2)
      ..write(obj.ticker)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.price)
      ..writeByte(6)
      ..write(obj.shares)
      ..writeByte(7)
      ..write(obj.amountKrw)
      ..writeByte(8)
      ..write(obj.exchangeRate)
      ..writeByte(9)
      ..write(obj.note)
      ..writeByte(10)
      ..write(obj._isInitialPurchase)
      ..writeByte(11)
      ..write(obj.realizedPnlKrw);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HoldingTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HoldingTransactionTypeAdapter
    extends TypeAdapter<HoldingTransactionType> {
  @override
  final int typeId = 14;

  @override
  HoldingTransactionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return HoldingTransactionType.buy;
      case 1:
        return HoldingTransactionType.sell;
      default:
        return HoldingTransactionType.buy;
    }
  }

  @override
  void write(BinaryWriter writer, HoldingTransactionType obj) {
    switch (obj) {
      case HoldingTransactionType.buy:
        writer.writeByte(0);
        break;
      case HoldingTransactionType.sell:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HoldingTransactionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
