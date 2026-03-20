// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MemoAdapter extends TypeAdapter<Memo> {
  @override
  final int typeId = 25;

  @override
  Memo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Memo(
      id: fields[0] as String,
      title: fields[1] as String,
      content: fields[2] as String,
      category:
          fields[3] == null ? MemoCategory.general : fields[3] as MemoCategory,
      isPinned: fields[4] == null ? false : fields[4] as bool,
      customDate: fields[7] as DateTime?,
      imageBase64List:
          fields[8] == null ? [] : (fields[8] as List?)?.cast<String>(),
      sortOrder: fields[9] == null ? 0 : fields[9] as int,
      createdAt: fields[5] as DateTime?,
      updatedAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Memo obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.isPinned)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt)
      ..writeByte(7)
      ..write(obj.customDate)
      ..writeByte(8)
      ..write(obj.imageBase64List)
      ..writeByte(9)
      ..write(obj.sortOrder);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MemoCategoryAdapter extends TypeAdapter<MemoCategory> {
  @override
  final int typeId = 26;

  @override
  MemoCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MemoCategory.general;
      case 1:
        return MemoCategory.analysis;
      case 2:
        return MemoCategory.insight;
      case 3:
        return MemoCategory.study;
      case 4:
        return MemoCategory.strategy;
      case 5:
        return MemoCategory.diary;
      default:
        return MemoCategory.general;
    }
  }

  @override
  void write(BinaryWriter writer, MemoCategory obj) {
    switch (obj) {
      case MemoCategory.general:
        writer.writeByte(0);
        break;
      case MemoCategory.analysis:
        writer.writeByte(1);
        break;
      case MemoCategory.insight:
        writer.writeByte(2);
        break;
      case MemoCategory.study:
        writer.writeByte(3);
        break;
      case MemoCategory.strategy:
        writer.writeByte(4);
        break;
      case MemoCategory.diary:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
