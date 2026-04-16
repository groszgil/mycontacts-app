// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_contact.dart';

class AppContactAdapter extends TypeAdapter<AppContact> {
  @override
  final int typeId = 0;

  @override
  AppContact read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    final primaryPhone = fields[2] as String? ?? '';
    var phones = (fields[3] as List?)?.cast<String>() ?? [];
    var phoneLabels = (fields[10] as List?)?.cast<String>() ?? [];
    var primaryPhoneIndex = (fields[11] as num?)?.toInt() ?? 0;

    // Migrate old data: phones was "additional phones", now it holds ALL phones.
    if (phones.isEmpty && primaryPhone.isNotEmpty) {
      phones = [primaryPhone];
      phoneLabels = ['נייד'];
      primaryPhoneIndex = 0;
    }
    while (phoneLabels.length < phones.length) phoneLabels.add('נייד');

    final email = fields[4] as String?;
    var emails = (fields[12] as List?)?.cast<String>() ?? [];
    var emailLabels = (fields[13] as List?)?.cast<String>() ?? [];

    // Migrate old data: single email → emails list.
    if (emails.isEmpty && email != null && email.isNotEmpty) {
      emails = [email];
      emailLabels = ['כללי'];
    }
    while (emailLabels.length < emails.length) emailLabels.add('כללי');

    return AppContact(
      id: fields[0] as String,
      name: fields[1] as String,
      primaryPhone: primaryPhone,
      phones: phones,
      email: email,
      whatsappPhone: fields[5] as String?,
      localPhotoPath: fields[6] as String?,
      categoryIds: (fields[7] as List?)?.cast<String>() ?? [],
      sortOrder: (fields[8] as num?)?.toInt() ?? 0,
      notes: fields[9] as String?,
      phoneLabels: phoneLabels,
      primaryPhoneIndex: primaryPhoneIndex,
      emails: emails,
      emailLabels: emailLabels,
      nickname: fields[14] as String?,
      birthdayMillis: (fields[15] as num?)?.toInt(),
      lastContactedMillis: (fields[16] as num?)?.toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, AppContact obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.effectivePrimaryPhone)
      ..writeByte(3)
      ..write(obj.phones)
      ..writeByte(4)
      ..write(obj.effectiveEmail)
      ..writeByte(5)
      ..write(null) // whatsappPhone deprecated
      ..writeByte(6)
      ..write(obj.localPhotoPath)
      ..writeByte(7)
      ..write(obj.categoryIds)
      ..writeByte(8)
      ..write(obj.sortOrder)
      ..writeByte(9)
      ..write(obj.notes)
      ..writeByte(10)
      ..write(obj.phoneLabels)
      ..writeByte(11)
      ..write(obj.primaryPhoneIndex)
      ..writeByte(12)
      ..write(obj.emails)
      ..writeByte(13)
      ..write(obj.emailLabels)
      ..writeByte(14)
      ..write(obj.nickname)
      ..writeByte(15)
      ..write(obj.birthdayMillis)
      ..writeByte(16)
      ..write(obj.lastContactedMillis);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppContactAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
