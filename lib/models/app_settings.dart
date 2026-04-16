import 'package:hive/hive.dart';

part 'app_settings.g.dart';

@HiveType(typeId: 2)
class AppSettings extends HiveObject {
  @HiveField(0)
  int gridColumns;

  @HiveField(1)
  int gridRows;

  @HiveField(2)
  bool isDarkMode;

  @HiveField(3)
  double fontScale;

  @HiveField(4)
  int accentColorValue;

  @HiveField(5)
  bool isListView;

  AppSettings({
    this.gridColumns = 3,
    this.gridRows = 4,
    this.isDarkMode = false,
    this.fontScale = 1.0,
    this.accentColorValue = 0xFF6C63FF,
    this.isListView = false,
  });
}
