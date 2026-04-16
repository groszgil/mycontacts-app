// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 2;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      gridColumns: (fields[0] as num?)?.toInt() ?? 3,
      gridRows: (fields[1] as num?)?.toInt() ?? 4,
      isDarkMode: fields[2] as bool? ?? false,
      fontScale: (fields[3] as num?)?.toDouble() ?? 1.0,
      accentColorValue: (fields[4] as num?)?.toInt() ?? 0xFF6C63FF,
      isListView: fields[5] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.gridColumns)
      ..writeByte(1)
      ..write(obj.gridRows)
      ..writeByte(2)
      ..write(obj.isDarkMode)
      ..writeByte(3)
      ..write(obj.fontScale)
      ..writeByte(4)
      ..write(obj.accentColorValue)
      ..writeByte(5)
      ..write(obj.isListView);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
