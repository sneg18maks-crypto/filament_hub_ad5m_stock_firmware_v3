import 'package:flutter/material.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'connect_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    Widget group(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 8),
              child: Text(title, style: TextStyle(color: mutedColor(context), fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            Panel(margin: EdgeInsets.zero, padding: EdgeInsets.zero, child: Column(children: children)),
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Я')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        Panel(
          child: Row(children: [
            const CircleAvatar(radius: 28, backgroundColor: Palette.green, child: Icon(Icons.person, size: 30, color: Colors.white)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Гость', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Локальный режим • без аккаунта', style: TextStyle(color: mutedColor(context), fontSize: 12)),
              ]),
            ),
            OutlinedButton(onPressed: () => snack(context, 'Облачный аккаунт появится позже'), child: const Text('Войти')),
          ]),
        ),
        group('Принтеры', [
          ListTile(
            leading: const Icon(Icons.wifi),
            title: const Text('Подключение и принтеры'),
            subtitle: Text(st.active?.name ?? 'Не выбран'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConnectPage())),
          ),
          ListTile(
            leading: Badge(isLabelVisible: st.unread > 0, label: Text('${st.unread}'), child: const Icon(Icons.notifications_outlined)),
            title: const Text('Уведомления'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage())),
          ),
        ]),
        group('Режим работы', [
          SwitchListTile(
            secondary: const Icon(Icons.science_outlined),
            title: const Text('Демо-режим'),
            subtitle: const Text('Симуляция принтера. Выключи для реальной работы'),
            value: st.demoMode,
            onChanged: st.setDemo,
          ),
        ]),
        group('Оформление', [
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Тёмная тема'),
            value: st.themeNotifier.value == ThemeMode.dark,
            onChanged: st.setDark,
          ),
          const ListTile(leading: Icon(Icons.language), title: Text('Язык'), trailing: Text('Русский')),
        ]),
        group('Уведомления', [
          SwitchListTile(title: const Text('Печать завершена'), value: st.notifyDone, onChanged: (v) => st.update(() => st.notifyDone = v)),
          SwitchListTile(title: const Text('Ошибки печати'), value: st.notifyError, onChanged: (v) => st.update(() => st.notifyError = v)),
          SwitchListTile(title: const Text('Мало филамента'), value: st.notifyLow, onChanged: (v) => st.update(() => st.notifyLow = v)),
          SwitchListTile(title: const Text('Высокая влажность катушки'), value: st.notifyHumidity, onChanged: (v) => st.update(() => st.notifyHumidity = v)),
        ]),
        group('О приложении', [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Filament Hub'),
            subtitle: const Text('Версия 0.2.0'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Filament Hub',
              applicationVersion: '0.2.0',
              children: const [Text('Управление 3D-принтером и RFID-катушками по Wi-Fi.')],
            ),
          ),
        ]),
      ]),
    );
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final list = st.notifications;
    IconData icon(String k) => switch (k) {
          'done' => Icons.check_circle,
          'error' => Icons.error,
          'warn' => Icons.warning_amber_rounded,
          _ => Icons.info,
        };
    Color color(String k) => switch (k) {
          'done' => Palette.green,
          'error' => Palette.red,
          'warn' => Palette.orange,
          _ => Palette.blue,
        };
    return Scaffold(
      appBar: AppBar(title: const Text('Уведомления'), actions: [
        TextButton(
          onPressed: () => st.update(() {
            for (final n in st.notifications) {
              n.read = true;
            }
          }),
          child: const Text('Прочитать все'),
        ),
      ]),
      body: list.isEmpty
          ? Center(child: Text('Нет уведомлений', style: TextStyle(color: mutedColor(context))))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final n = list[i];
                return Panel(
                  margin: const EdgeInsets.only(bottom: 10),
                  onTap: () => st.update(() => n.read = true),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(icon(n.kind), color: color(n.kind)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w500 : FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(n.body, style: TextStyle(color: mutedColor(context), fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(fmtDate(n.time), style: TextStyle(color: mutedColor(context), fontSize: 11)),
                      ]),
                    ),
                    if (!n.read) const Icon(Icons.circle, size: 10, color: Palette.green),
                  ]),
                );
              },
            ),
    );
  }
}
