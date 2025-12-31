import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'lesson_room.dart';
import '../main.dart';

class LessonsPage extends StatefulWidget {
  const LessonsPage({super.key});
  @override
  State<LessonsPage> createState() => _LessonsPageState();
}

class _LessonsPageState extends State<LessonsPage> {
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (currentUser.value != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.value!.id)
          .get();
      if (mounted && doc.exists) {
        setState(() => _userData = doc.data());
      }
    }
  }

  String _genCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(
      6,
      (_) => chars[Random().nextInt(chars.length)],
    ).join();
  }

  void _createDialog() {
    final titleCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String privacy = 'public';
    String? stage;
    final List<dynamic> rawStages = _userData?['stages'] ?? [];
    final List<String> stages = rawStages.map((e) => e.toString()).toList();

    // Ensure the subject is retrieved correctly or allow selection
    String? subject = _userData?['subject'];
    final List<String> allSubjects = [
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setS) => AlertDialog(
          title: const Text('إنشاء درس'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'العنوان'),
                ),
                const SizedBox(height: 12),
                if (stages.isNotEmpty)
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'المرحلة'),
                    items: stages
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setS(() => stage = v),
                  )
                else
                  const Text(
                    'لا توجد مراحل مسجلة',
                    style: TextStyle(color: Colors.red),
                  ),
                const SizedBox(height: 12),
                // Subject Dropdown (Auto-filled but editable if user wants to change or if it was empty)
                DropdownButtonFormField<String>(
                  value: allSubjects.contains(subject) ? subject : null,
                  decoration: const InputDecoration(labelText: 'المادة'),
                  items: allSubjects
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => subject = v,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: privacy,
                  items: const [
                    DropdownMenuItem(value: 'public', child: Text('عام')),
                    DropdownMenuItem(
                      value: 'private',
                      child: Text('خاص (كلمة مرور)'),
                    ),
                    DropdownMenuItem(
                      value: 'unlisted',
                      child: Text('غير مدرج (كود)'),
                    ),
                  ],
                  onChanged: (v) => setS(() => privacy = v!),
                  decoration: const InputDecoration(labelText: 'الخصوصية'),
                ),
                if (privacy == 'private') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    decoration: const InputDecoration(labelText: 'كلمة المرور'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty || stage == null || subject == null)
                  return;

                final ref = await FirebaseFirestore.instance
                    .collection('lessons')
                    .add({
                      'title': titleCtrl.text,
                      'teacher': _userData?['name'],
                      'teacherId': currentUser.value!.id,
                      'stage': stage,
                      'subject': subject,
                      'privacy': privacy,
                      'password': passCtrl.text,
                      'code': _genCode(),
                      'active': true,
                      'startTime': FieldValue.serverTimestamp(),
                    });
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LessonRoomPage(lessonId: ref.id),
                    ),
                  );
                }
              },
              child: const Text('إنشاء'),
            ),
          ],
        ),
      ),
    );
  }

  void _joinDialog() {
    final codeCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('انضمام بكود'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(labelText: 'الكود'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passCtrl,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور (اختياري)',
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final q = await FirebaseFirestore.instance
                  .collection('lessons')
                  .where('code', isEqualTo: codeCtrl.text.trim())
                  .where('active', isEqualTo: true)
                  .get();

              if (q.docs.isNotEmpty) {
                final d = q.docs.first;
                if (d['privacy'] == 'private' &&
                    d['password'] != passCtrl.text) {
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('كلمة المرور خطأ')),
                    );
                  return;
                }
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LessonRoomPage(lessonId: d.id),
                    ),
                  );
                }
              } else {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('الغرفة غير موجودة')),
                  );
              }
            },
            child: const Text('دخول'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userData == null && currentUser.value != null)
      return const Center(child: CircularProgressIndicator());

    final isTeacher = _userData?['role'] == 'teacher';
    final myStages = List<String>.from(_userData?['stages'] ?? []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الدروس'),
        actions: [
          IconButton(icon: const Icon(Icons.keyboard), onPressed: _joinDialog),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('lessons')
            .where('active', isEqualTo: true)
            .orderBy('startTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            if (isTeacher) return data['teacherId'] == currentUser.value!.id;
            if (data['privacy'] == 'unlisted') return false;
            return myStages.contains(data['stage']);
          }).toList();

          if (docs.isEmpty)
            return const Center(child: Text('لا توجد دروس متاحة'));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final isPrivate = data['privacy'] == 'private';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.class_)),
                  title: Text(data['title']),
                  subtitle: Text(
                    '${data['subject'] ?? ''} - ${data['stage']}\n${data['teacher']}',
                  ),
                  trailing: isPrivate ? const Icon(Icons.lock, size: 16) : null,
                  onTap: () {
                    if (isPrivate) {
                      final c = TextEditingController();
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('كلمة المرور'),
                          content: TextField(controller: c),
                          actions: [
                            ElevatedButton(
                              onPressed: () {
                                if (c.text == data['password']) {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          LessonRoomPage(lessonId: docs[i].id),
                                    ),
                                  );
                                }
                              },
                              child: const Text('دخول'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LessonRoomPage(lessonId: docs[i].id),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: isTeacher
          ? FloatingActionButton(
              onPressed: _createDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
