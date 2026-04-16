import 'package:hive/hive.dart';

part 'category.g.dart';

@HiveType(typeId: 1)
class Category extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late int colorValue;

  @HiveField(3)
  late int sortOrder;

  Category({
    required this.id,
    required this.name,
    required this.colorValue,
    this.sortOrder = 0,
  });
}
