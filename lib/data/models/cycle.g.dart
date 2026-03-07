// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cycle.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CycleAdapter extends TypeAdapter<Cycle> {
  @override
  final int typeId = 1;

  @override
  Cycle read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Cycle(
      id: fields[0] as String,
      ticker: fields[1] as String,
      name: fields[2] as String,
      seedAmount: fields[3] == null ? 0.0 : fields[3] as double,
      exchangeRateAtEntry: fields[11] == null ? 0.0 : fields[11] as double,
      strategyType: fields[12] == null
          ? StrategyType.alphaCycleV3
          : fields[12] as StrategyType,
      entryPrice: fields[13] as double?,
      consecutiveProfitCount: fields[14] == null ? 0 : fields[14] as int,
      panicBuyUsed: fields[15] == null ? false : fields[15] as bool,
      roundsUsed: fields[16] == null ? 0 : fields[16] as int,
      totalRounds: fields[17] == null ? 40 : fields[17] as int,
      initialEntryRatio: fields[18] == null ? 0.2 : fields[18] as double,
      weightedBuyThreshold: fields[19] == null ? -20.0 : fields[19] as double,
      weightedBuyDivisor: fields[20] == null ? 1000.0 : fields[20] as double,
      panicBuyThreshold: fields[21] == null ? -50.0 : fields[21] as double,
      panicBuyMultiplier: fields[22] == null ? 0.5 : fields[22] as double,
      firstProfitTarget: fields[23] == null ? 30.0 : fields[23] as double,
      profitTargetStep: fields[24] == null ? 5.0 : fields[24] as double,
      minProfitTarget: fields[25] == null ? 10.0 : fields[25] as double,
      cashSecureRatio: fields[26] == null ? 0.3333 : fields[26] as double,
      takeProfitPercent: fields[27] == null ? 10.0 : fields[27] as double,
      completedReturnRate: fields[10] as double?,
      startDate: fields[8] as DateTime?,
    )
      ..averagePrice = fields[4] == null ? 0.0 : fields[4] as double
      ..totalShares = fields[5] == null ? 0.0 : fields[5] as double
      ..remainingCash = fields[6] == null ? 0.0 : fields[6] as double
      ..status =
          fields[7] == null ? CycleStatus.active : fields[7] as CycleStatus
      ..updatedAt = fields[9] as DateTime;
  }

  @override
  void write(BinaryWriter writer, Cycle obj) {
    writer
      ..writeByte(28)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.ticker)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.seedAmount)
      ..writeByte(4)
      ..write(obj.averagePrice)
      ..writeByte(5)
      ..write(obj.totalShares)
      ..writeByte(6)
      ..write(obj.remainingCash)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.startDate)
      ..writeByte(9)
      ..write(obj.updatedAt)
      ..writeByte(10)
      ..write(obj.completedReturnRate)
      ..writeByte(11)
      ..write(obj.exchangeRateAtEntry)
      ..writeByte(12)
      ..write(obj.strategyType)
      ..writeByte(13)
      ..write(obj.entryPrice)
      ..writeByte(14)
      ..write(obj.consecutiveProfitCount)
      ..writeByte(15)
      ..write(obj.panicBuyUsed)
      ..writeByte(16)
      ..write(obj.roundsUsed)
      ..writeByte(17)
      ..write(obj.totalRounds)
      ..writeByte(18)
      ..write(obj.initialEntryRatio)
      ..writeByte(19)
      ..write(obj.weightedBuyThreshold)
      ..writeByte(20)
      ..write(obj.weightedBuyDivisor)
      ..writeByte(21)
      ..write(obj.panicBuyThreshold)
      ..writeByte(22)
      ..write(obj.panicBuyMultiplier)
      ..writeByte(23)
      ..write(obj.firstProfitTarget)
      ..writeByte(24)
      ..write(obj.profitTargetStep)
      ..writeByte(25)
      ..write(obj.minProfitTarget)
      ..writeByte(26)
      ..write(obj.cashSecureRatio)
      ..writeByte(27)
      ..write(obj.takeProfitPercent);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CycleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StrategyTypeAdapter extends TypeAdapter<StrategyType> {
  @override
  final int typeId = 20;

  @override
  StrategyType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return StrategyType.alphaCycleV3;
      case 1:
        return StrategyType.infiniteBuy;
      default:
        return StrategyType.alphaCycleV3;
    }
  }

  @override
  void write(BinaryWriter writer, StrategyType obj) {
    switch (obj) {
      case StrategyType.alphaCycleV3:
        writer.writeByte(0);
        break;
      case StrategyType.infiniteBuy:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StrategyTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CycleStatusAdapter extends TypeAdapter<CycleStatus> {
  @override
  final int typeId = 10;

  @override
  CycleStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CycleStatus.active;
      case 1:
        return CycleStatus.completed;
      default:
        return CycleStatus.active;
    }
  }

  @override
  void write(BinaryWriter writer, CycleStatus obj) {
    switch (obj) {
      case CycleStatus.active:
        writer.writeByte(0);
        break;
      case CycleStatus.completed:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CycleStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
