# Filament Hub — Flutter + FlashForge Adventurer 5M

## Реальная отправка на FlashForge AD5M со штатной прошивкой

Приложение больше не требует Klipper/Moonraker для отправки G-code на Adventurer 5M.
Используется штатная локальная HTTP API FlashForge на порту **8898**.

1. Подключи AD5M и телефон к одной Wi-Fi сети.
2. На экране принтера открой настройки сети и включи **LAN Only**.
3. Запиши IP-адрес, Serial Number и Check Code, показанные в сетевых настройках.
4. В Filament Hub открой «Подключение» → «Добавить принтер вручную».
5. Выбери «FlashForge Adventurer 5M (штатная прошивка)», введи IP, Serial Number и Check Code. Порт оставь `8898`.
6. Выключи демо-режим и нажми «Проверить связь».
7. Для отправки выбери подготовленный под AD5M файл **.gcode**. Можно включить «Сразу начать печать».

Важно:
- Отправка реализована через `POST /uploadGcode` с `gcodeFile`, `fileSize`, `serialNumber`, `checkCode`, `printNow` и `levelingBeforePrint`.
- Для запуска уже загруженного файла используется `/printGcode`.
- Файл G-code должен быть заранее нарезан профилем именно для FlashForge Adventurer 5M. STL/ненарезанный 3MF требуют отдельного сервера нарезки и корректного профиля AD5M.
- Это LAN-подключение: для первой проверки телефон и принтер должны быть в одной локальной сети.
- API штатной прошивки не является Moonraker. Некоторые расширенные функции интерфейса (например, ручное перемещение осей, удаление файлов и аварийная остановка) пока не подключены к FlashForge и могут показывать сообщение о неподдерживаемой функции.
- Реальная проверка загрузки требует самого принтера; код подготовлен по опубликованной документации протокола, но здесь не мог быть испытан на физическом AD5M.

## Сборка APK на Windows

1. Установи Flutter SDK и Git.
2. Распакуй архив проекта.
3. Открой папку `filament_hub` в VS Code.
4. В терминале VS Code выполни:

```bash
flutter create . --platforms=android
flutter pub get
```

5. В `android/app/src/main/AndroidManifest.xml` добавь перед `<application>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

6. В открывающий тег `<application ...>` добавь:

```xml
android:usesCleartextTraffic="true"
```

Это требуется для локального HTTP API принтера (`http://IP:8898`).

7. Собери APK:

```bash
flutter build apk --release
```

Готовый файл появится здесь:

`build/app/outputs/flutter-apk/app-release.apk`

Установи APK на Android-телефон и подключись к той же Wi-Fi сети, что и принтер.

## Остальные функции

Moonraker/Klipper профиль сохранён для других принтеров. Деморежим, экраны RFID, каталог и часть управления остаются демонстрационными. FlashForge AD5M добавлен отдельным типом подключения и не требует установки сторонней прошивки.
