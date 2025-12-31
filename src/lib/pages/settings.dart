import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../main.dart';
import 'welcome.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ThemeMode _mode = themeNotifier.value;
  void _setTheme(ThemeMode? m) async {
    if (m == null) return;
    setState(() => _mode = m);
    themeNotifier.value = m;
    final p = await SharedPreferences.getInstance();
    if (m == ThemeMode.system)
      p.remove('themeMode');
    else
      p.setString('themeMode', m == ThemeMode.light ? 'light' : 'dark');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'المظهر',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          RadioListTile(
            title: const Text('النظام'),
            value: ThemeMode.system,
            groupValue: _mode,
            onChanged: _setTheme,
          ),
          RadioListTile(
            title: const Text('فاتح'),
            value: ThemeMode.light,
            groupValue: _mode,
            onChanged: _setTheme,
          ),
          RadioListTile(
            title: const Text('داكن'),
            value: ThemeMode.dark,
            groupValue: _mode,
            onChanged: _setTheme,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('تعديل البيانات'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    WelcomePage(user: currentUser.value, forceShowForm: true),
              ),
            ),
          ),
          const Divider(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('حذف الحساب'),
                  content: const Text('تأكيد الحذف؟'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('إلغاء'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('حذف'),
                    ),
                  ],
                ),
              );
              if (ok == true && currentUser.value != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser.value!.id)
                    .delete();
                await GoogleSignIn().signOut();
                currentUser.value = null;
                if (mounted)
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const WelcomePage()),
                    (r) => false,
                  );
              }
            },
            child: const Text('حذف الحساب نهائياً'),
          ),
        ],
      ),
    );
  }
}
