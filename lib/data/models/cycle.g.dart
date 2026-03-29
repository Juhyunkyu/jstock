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
      weightedBuyPerPercent: fields[20] == null ? 0.0 : fields[20] as double,
      panicBuyThreshold: fields[21] == null ? -50.0 : fields[21] as double,
      panicBuyMultiplier: fields[22] == null ? 0.5 : fields[22] as double,
      firstProfitTarget: fields[23] == null ? 30.0 : fields[23] as double,
      profitTargetStep: fields[24] == null ? 5.0 : fields[24] as double,
      minProfitTarget: fields[25] == null ? 10.0 : fields[25] as double,
      cashSecureRatio: fields[26] == null ? 0.3333 : fields[26] as double,
      takeProfitPercent: fields[27] == null ? 10.0 : fields[27] as double,
      nickname: fields[28] == null ? '' : fields[28] as String,
      steadyVersion:
          fields[29] == null ? SteadyVersion.v1 : fields[29] as SteadyVersion,
      sellQuarterPercent: fields[30] == null ? 0.25 : fields[30] as double,
      compoundEnabled: fields[31] == null ? false : fields[31] as bool,
      offsetA: fields[32] == null ? 15.0 : fields[32] as double,
      offsetB: fields[33] == null ? 1.5 : fields[33] as double,
      quarterModeOffset: fields[34] == null ? -15.0 : fields[34] as double,
      isQuarterStopLossMode: fields[35] == null ? false : fields[35] as bool,
      quarterStopLossRoundsUsed: fields[36] == null ? 0 : fields[36] as int,
      completedReturnRate: fields[10] as double?,
      startDate: fields[8] as DateTime?,
    )
      ..averagePrice = fields[4] == null ? 0.0 : fields[4] as double
      ..totalShares = fields[5] == null ? 0.0 : fields[5] as double
      ..remainingCash = fields[6] == null ? 0.0 : fields[6] as double
      ..status =
          fields[7] == null ? CycleStatus.active : fields[7] as CycleStatus
      ..updatedAt = fields[9] as DateTime
      ..totalBuyAmountKrw = fields[37] == null ? 0.0 : fields[37] as double
      ..totalSellAmountKrw = fields[38] == null ? 0.0 : fields[38] as double
      ..firstTradeDate = fields[39] as DateTime?
      ..lastTradeDate = fields[40] as DateTime?
      ..totalBuyUsd = fields[41] == null ? 0.0 : fields[41] as double
      ..totalSellUsd = fields[42] == null ? 0.0 : fields[42] as double
      ..athPrice = fields[43] == null ? 0.0 : fields[43] as double
      ..ladderMode = fields[44] == null ? 1 : fields[44] as int
      ..currentStep = fields[45] == null ? 0 : fields[45] as int
      ..ladderSteps = fields[46] == null ? 6 : fields[46] as int
      ..ladderWeights =
          fields[47] == null ? '1,1,2,3,4,5' : fields[47] as String
      ..ladderTriggers = fields[48] == null
          ? '-10,-19,-28,-37,-46,-55'
          : fields[48] as String
      ..buyTicker = fields[49] == null ? '' : fields[49] as String
      ..buyTicker1x = fields[50] == null ? '' : fields[50] as String
      ..buyTicker2x = fields[51] == null ? '' : fields[51] as String
      ..buyTicker3x = fields[52] == null ? '' : fields[52] as String;
  }

  @override
  void write(BinaryWriter writer, Cycle obj) {
    writer
      ..writeByte(53)
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
      ..write(obj.weightedBuyPerPercent)
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
      ..write(obj.takeProfitPercent)
      ..writeByte(28)
      ..write(obj.nickname)
      ..writeByte(29)
      ..write(obj.steadyVersion)
      ..writeByte(30)
      ..write(obj.sellQuarterPercent)
      ..writeByte(31)
      ..write(obj.compoundEnabled)
      ..writeByte(32)
      ..write(obj.offsetA)
      ..writeByte(33)
      ..write(obj.offsetB)
      ..writeByte(34)
      ..write(obj.quarterModeOffset)
      ..writeByte(35)
      ..write(obj.isQuarterStopLossMode)
      ..writeByte(36)
      ..write(obj.quarterStopLossRoundsUsed)
      ..writeByte(37)
      ..write(obj.totalBuyAmountKrw)
      ..writeByte(38)
      ..write(obj.totalSellAmountKrw)
      ..writeByte(39)
      ..write(obj.firstTradeDate)
      ..writeByte(40)
      ..write(obj.lastTradeDate)
      ..writeByte(41)
      ..write(obj.totalBuyUsd)
      ..writeByte(42)
      ..write(obj.totalSellUsd)
      ..writeByte(43)
      ..write(obj.athPrice)
      ..writeByte(44)
      ..write(obj.ladderMode)
      ..writeByte(45)
      ..write(obj.currentStep)
      ..writeByte(46)
      ..write(obj.ladderSteps)
      ..writeByte(47)
      ..write(obj.ladderWeights)
      ..writeByte(48)
      ..write(obj.ladderTriggers)
      ..writeByte(49)
      ..write(obj.buyTicker)
      ..writeByte(50)
      ..write(obj.buyTicker1x)
      ..writeByte(51)
      ..write(obj.buyTicker2x)
      ..writeByte(52)
      ..write(obj.buyTicker3x);
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
      case 2:
        return StrategyType.ladderCycle;
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
      case StrategyType.ladderCycle:
        writer.writeByte(2);
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

class SteadyVersionAdapter extends TypeAdapter<SteadyVersion> {
  @override
  final int typeId = 24;

  @override
  SteadyVersion read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SteadyVersion.v1;
      case 1:
        return SteadyVersion.v2_2;
      case 2:
        return SteadyVersion.v3_0;
      default:
        return SteadyVersion.v1;
    }
  }

  @override
  void write(BinaryWriter writer, SteadyVersion obj) {
    switch (obj) {
      case SteadyVersion.v1:
        writer.writeByte(0);
        break;
      case SteadyVersion.v2_2:
        writer.writeByte(1);
        break;
      case SteadyVersion.v3_0:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SteadyVersionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
