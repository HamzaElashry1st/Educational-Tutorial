import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import 'layout.dart';

class WelcomePage extends StatefulWidget {
  final GoogleSignInAccount? user;
  final bool forceShowForm;
  const WelcomePage({super.key, this.user, this.forceShowForm = false});
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _showForm = false;
  String? _role;
  String? _subject;
  final List<String> _teacherStages = [];
  String? _studentStage;
  bool _isLoading = false;

  final List<String> _subjects = [
    'الرياضيات',
    'العلوم',
    'اللغة العربية',
    'التربية الدينية',
    'الحاسب الآلي',
    'اللغة الإنجليزية',
    'الدراسات الاجتماعية',
    'الفيزياء',
    'الكيمياء',
    'الأحياء',
    'التاريخ',
    'الجغرافيا',
    'الفلسفة',
    'علم النفس',
  ];

  final List<String> _stages = [
    'الصف الرابع الابتدائي',
    'الصف الخامس الابتدائي',
    'الصف السادس الابتدائي',
    'الصف الأول الإعدادي',
    'الصف الثاني الإعدادي',
    'الصف الثالث الإعدادي',
    'الصف الأول الثانوي',
    'الصف الثاني الثانوي',
    'الصف الثالث الثانوي',
  ];

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.forceShowForm) _showForm = true;
  }

  Future<void> _handleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final user = await GoogleSignIn().signIn();
      if (user != null) {
        currentUser.value = user;

        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .get();

        if (doc.exists && doc.data()?['completedFirstTimeSetup'] == true) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MainPage()),
            );
          }
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;
    if (_role == null) return _snack('اختر الدور');
    if (_role == 'teacher' && (_subject == null || _teacherStages.isEmpty)) {
      return _snack('أكمل بيانات المعلم');
    }
    if (_role == 'student' && _studentStage == null) {
      return _snack('اختر المرحلة');
    }

    setState(() => _isLoading = true);
    try {
      final stages = _role == 'teacher' ? _teacherStages : [_studentStage!];
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user!.id)
          .set({
            'role': _role,
            'subject': _role == 'teacher' ? _subject : null,
            'stages': stages,
            'name': widget.user!.displayName,
            'email': widget.user!.email,
            'photoUrl': widget.user!.photoUrl,
            'completedFirstTimeSetup': true,
            'createdAt': FieldValue.serverTimestamp(),
            'friends': [],
          }, SetOptions(merge: true));
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainPage()),
        );
      }
    } catch (e) {
      _snack('خطأ: $e');
      setState(() => _isLoading = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    if (_showForm && widget.user != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('إكمال الملف الشخصي')),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Text(
                      'أنا:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile(
                            title: const Text('معلم'),
                            value: 'teacher',
                            groupValue: _role,
                            onChanged: (v) => setState(() => _role = v),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile(
                            title: const Text('طالب'),
                            value: 'student',
                            groupValue: _role,
                            onChanged: (v) => setState(() => _role = v),
                          ),
                        ),
                      ],
                    ),
                    if (_role == 'teacher') ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField(
                        decoration: const InputDecoration(labelText: 'المادة'),
                        items: _subjects
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _subject = v),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'المراحل:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Wrap(
                        spacing: 8,
                        children: _stages
                            .map(
                              (s) => FilterChip(
                                label: Text(s),
                                selected: _teacherStages.contains(s),
                                onSelected: (sel) => setState(
                                  () => sel
                                      ? _teacherStages.add(s)
                                      : _teacherStages.remove(s),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (_role == 'student') ...[
                      const SizedBox(height: 16),
                      const Text(
                        'المرحلة الدراسية:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Column(
                        children: _stages
                            .map(
                              (s) => RadioListTile(
                                title: Text(s),
                                value: s,
                                groupValue: _studentStage,
                                onChanged: (v) =>
                                    setState(() => _studentStage = v),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _saveData,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const Text('حفظ'),
                    ),
                  ],
                ),
              ),
      );
    }
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cast_for_education,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              const Text(
                'الدليل التعليمي',
                style: TextStyle(fontSize: 32, fontFamily: 'ArR'),
              ),
              const SizedBox(height: 48),
              if (_isLoading)
                const CircularProgressIndicator()
              else ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('دخول عبر Google'),
                  onPressed: _handleSignIn,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const MainPage()),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('دخول كزائر'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
