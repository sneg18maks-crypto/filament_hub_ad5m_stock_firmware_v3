import 'package:flutter/material.dart';
import 'models.dart';

final List<FilamentData> mockSpools = [
  FilamentData(id: 's1', type: 'PLA', brand: 'eSUN', colorName: 'Оранжевый', color: const Color(0xFFFF7A00), humidity: 18, weightG: 742, tempC: 215, minTemp: 190, maxTemp: 230, bedTemp: 60),
  FilamentData(id: 's2', type: 'PETG', brand: 'Polymaker', colorName: 'Чёрный', color: const Color(0xFF222222), humidity: 27, weightG: 480, tempC: 240, minTemp: 230, maxTemp: 260, bedTemp: 80),
  FilamentData(id: 's3', type: 'PLA', brand: 'Bambu', colorName: 'Белый', color: const Color(0xFFF2F2F2), humidity: 15, weightG: 910, tempC: 215, minTemp: 190, maxTemp: 230, bedTemp: 55),
  FilamentData(id: 's4', type: 'TPU', brand: 'Filamentarno', colorName: 'Синий', color: const Color(0xFF1E6BFF), humidity: 33, weightG: 230, tempC: 225, minTemp: 210, maxTemp: 240, bedTemp: 50),
  FilamentData(id: 's5', type: 'ABS', brand: 'REC', colorName: 'Серый', color: const Color(0xFF8A9096), humidity: 22, weightG: 650, tempC: 250, minTemp: 235, maxTemp: 270, bedTemp: 100),
  FilamentData(id: 's6', type: 'PLA Silk', brand: 'eSUN', colorName: 'Золотой', color: const Color(0xFFD4AF37), humidity: 41, weightG: 95, tempC: 220, minTemp: 200, maxTemp: 235, bedTemp: 60),
  FilamentData(id: 's7', type: 'PLA', brand: 'Bambu', colorName: 'Зелёный', color: const Color(0xFF2FBF71), humidity: 19, weightG: 1000, tempC: 215, minTemp: 190, maxTemp: 230, bedTemp: 55),
  FilamentData(id: 's8', type: 'ASA', brand: 'Fiberlogy', colorName: 'Красный', color: const Color(0xFFD62828), humidity: 24, weightG: 820, tempC: 255, minTemp: 240, maxTemp: 270, bedTemp: 95),
];

List<PrintRecord> mockHistory() {
  final now = DateTime.now();
  PrintRecord r(String n, int daysAgo, int min, double g, bool ok, Color c, String t) => PrintRecord(
      name: n, date: now.subtract(Duration(days: daysAgo, hours: 2)), duration: Duration(minutes: min), grams: g, success: ok, color: c, type: t);
  return [
    r('Benchy.gcode', 1, 68, 14, true, const Color(0xFFFF7A00), 'PLA'),
    r('Phone_stand.gcode', 2, 142, 38, true, const Color(0xFF222222), 'PETG'),
    r('Cable_clip_x10.gcode', 3, 95, 21, true, const Color(0xFFF2F2F2), 'PLA'),
    r('Vase_spiral.gcode', 5, 210, 52, false, const Color(0xFFD4AF37), 'PLA Silk'),
    r('Gear_box.gcode', 6, 305, 87, true, const Color(0xFF8A9096), 'ABS'),
    r('Flexi_dragon.gcode', 8, 180, 45, true, const Color(0xFF1E6BFF), 'TPU'),
    r('Planter_pot.gcode', 10, 250, 72, true, const Color(0xFF2FBF71), 'PLA'),
    r('Headset_hook.gcode', 12, 55, 12, true, const Color(0xFFD62828), 'ASA'),
  ];
}

List<GcodeFile> mockFiles() {
  final now = DateTime.now();
  GcodeFile f(String n, double mb, int min, double g, int d) =>
      GcodeFile(name: n, sizeMb: mb, modified: now.subtract(Duration(days: d)), est: Duration(minutes: min), grams: g);
  return [
    f('Gridfinity_baseplate_4x4.gcode', 12.4, 200, 96, 0),
    f('Benchy.gcode', 3.1, 68, 14, 1),
    f('Phone_stand.gcode', 6.8, 142, 38, 2),
    f('Cable_clip_x10.gcode', 4.2, 95, 21, 3),
    f('Planter_pot.gcode', 9.7, 250, 72, 10),
    f('Calibration_cube.gcode', 1.1, 28, 6, 14),
  ];
}

List<AppNotification> mockNotifications() {
  final now = DateTime.now();
  return [
    AppNotification(title: 'Мало пластика', body: 'PLA Silk Золотой: осталось 95 г', kind: 'warn', time: now.subtract(const Duration(hours: 3))),
    AppNotification(title: 'Печать завершена', body: 'Benchy.gcode напечатан за 1ч 8м', kind: 'done', time: now.subtract(const Duration(days: 1))),
    AppNotification(title: 'Ошибка печати', body: 'Vase_spiral.gcode: отклеился от стола на слое 112', kind: 'error', time: now.subtract(const Duration(days: 5))),
    AppNotification(title: 'Добро пожаловать', body: 'Это демо-режим: данные принтера симулируются.', kind: 'info', time: now.subtract(const Duration(days: 6)), read: true),
  ];
}

final List<ModelItem> mockModels = [
  ModelItem(id: 'm1', title: 'Gridfinity базовая плита', author: 'Zack Freedman', category: 'Полезное', description: 'Модульная система хранения. Печатай плиты любого размера и вставляй контейнеры.', likes: 18420, downloads: 96300, hours: 3.3, grams: 96, c1: const Color(0xFF00AE42), c2: const Color(0xFF005F25), icon: Icons.grid_view),
  ModelItem(id: 'm2', title: 'Подставка для телефона', author: 'MakerAnna', category: 'Полезное', description: 'Складная подставка с регулировкой угла. Печатается без поддержек.', likes: 5210, downloads: 22100, hours: 2.4, grams: 38, c1: const Color(0xFF0A84FF), c2: const Color(0xFF0646A6), icon: Icons.phone_android),
  ModelItem(id: 'm3', title: 'Flexi дракон', author: 'McGybeer', category: 'Игрушки', description: 'Подвижный дракон, печатается целиком за один раз. Лучше шёлковым PLA.', likes: 30210, downloads: 210400, hours: 3.0, grams: 45, c1: const Color(0xFFFF9F0A), c2: const Color(0xFFB23A00), icon: Icons.pets, material: 'PLA Silk'),
  ModelItem(id: 'm4', title: 'Органайзер для кабелей', author: 'Cableguy', category: 'Полезное', description: 'Клипсы для проводов на край стола. Набор из 10 штук.', likes: 3120, downloads: 15800, hours: 1.6, grams: 21, c1: const Color(0xFF8E8E93), c2: const Color(0xFF3A3A3C), icon: Icons.cable),
  ModelItem(id: 'm5', title: 'Спиральная ваза', author: 'VaseLab', category: 'Декор', description: 'Тонкостенная ваза в режиме спирали. Идеальна для прозрачного PETG.', likes: 8650, downloads: 41200, hours: 3.5, grams: 52, c1: const Color(0xFFBF5AF2), c2: const Color(0xFF5E2B8F), icon: Icons.local_florist, material: 'PETG'),
  ModelItem(id: 'm6', title: 'Горшок для суккулентов', author: 'GreenThumb', category: 'Декор', description: 'Горшок с поддоном для воды. Дренажные отверстия уже в модели.', likes: 4380, downloads: 18700, hours: 4.2, grams: 72, c1: const Color(0xFF30D158), c2: const Color(0xFF0B6B2B), icon: Icons.park),
  ModelItem(id: 'm7', title: 'Редуктор планетарный', author: 'GearHead', category: 'Запчасти', description: 'Рабочий планетарный редуктор 5:1. Нужна смазка и аккуратная калибровка.', likes: 6740, downloads: 29800, hours: 5.1, grams: 87, c1: const Color(0xFF64D2FF), c2: const Color(0xFF1B6C8F), icon: Icons.settings, material: 'ABS'),
  ModelItem(id: 'm8', title: 'Крючок для наушников', author: 'DeskPro', category: 'Полезное', description: 'Крепится под столешницу на двусторонний скотч.', likes: 2210, downloads: 9400, hours: 0.9, grams: 12, c1: const Color(0xFFFF453A), c2: const Color(0xFF8E1B14), icon: Icons.headphones),
  ModelItem(id: 'm9', title: 'Держатель геймпада', author: 'PlayFab', category: 'Игрушки', description: 'Универсальная подставка под геймпады Xbox и PlayStation.', likes: 7890, downloads: 35600, hours: 2.8, grams: 55, c1: const Color(0xFF5E5CE6), c2: const Color(0xFF2B2A8C), icon: Icons.sports_esports),
  ModelItem(id: 'm10', title: 'Ракета-брелок', author: 'SpaceKid', category: 'Игрушки', description: 'Маленький брелок-ракета. Быстро печатается, отличный подарок.', likes: 1980, downloads: 12900, hours: 0.7, grams: 6, c1: const Color(0xFFFF375F), c2: const Color(0xFF8C1530), icon: Icons.rocket_launch),
  ModelItem(id: 'm11', title: 'Кронштейн катушки', author: 'FilamentFan', category: 'Инструменты', description: 'Держатель катушки на ось 8 мм с подшипниками 608.', likes: 9120, downloads: 53100, hours: 2.2, grams: 64, c1: const Color(0xFFFFD60A), c2: const Color(0xFF9A7B00), icon: Icons.album),
  ModelItem(id: 'm12', title: 'Набор ключей-шестигранников', author: 'ToolBox', category: 'Инструменты', description: 'Хранилище на стену для набора шестигранников 1.5–10 мм.', likes: 4520, downloads: 20300, hours: 3.9, grams: 78, c1: const Color(0xFF98989D), c2: const Color(0xFF48484A), icon: Icons.build),
  ModelItem(id: 'm13', title: 'Корпус для Raspberry Pi 4', author: 'PiCases', category: 'Запчасти', description: 'Корпус с вентиляцией и креплением под 30 мм кулер.', likes: 11300, downloads: 74400, hours: 2.6, grams: 41, c1: const Color(0xFFFF2D55), c2: const Color(0xFF7C1228), icon: Icons.memory),
  ModelItem(id: 'm14', title: 'Подставка под кружку', author: 'CoffeeLab', category: 'Декор', description: 'Шестигранные костеры с объёмным узором. Набор из 4 штук.', likes: 2760, downloads: 11200, hours: 1.4, grams: 28, c1: const Color(0xFFAC8E68), c2: const Color(0xFF5C4630), icon: Icons.coffee),
];

const List<String> modelCategories = ['Все', 'Полезное', 'Игрушки', 'Декор', 'Запчасти', 'Инструменты'];
