import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات', style: TextStyle(fontFamily: 'UI')),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.value!.id)
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty)
            return const Center(child: Text('لا توجد إشعارات'));

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              if (data['read'] == false) {
                doc.reference.update({'read': true});
              }

              return Card(
                color: data['read'] ? Colors.white : Colors.blue[50],
                child: ListTile(
                  leading: Icon(
                    data['type'] == 'friend_request'
                        ? Icons.person_add
                        : Icons.notifications,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: Text(data['title'] ?? 'إشعار جديد'),
                  subtitle: Text(
                    data['body'] ??
                        (data['type'] == 'friend_request'
                            ? 'طلب صداقة من ${data['fromName']}'
                            : ''),
                  ),
                  trailing: data['type'] == 'friend_request'
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.check,
                                color: Colors.green,
                              ),
                              onPressed: () async {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(currentUser.value!.id)
                                    .update({
                                      'friends': FieldValue.arrayUnion([
                                        data['fromId'],
                                      ]),
                                    });
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(data['fromId'])
                                    .update({
                                      'friends': FieldValue.arrayUnion([
                                        currentUser.value!.id,
                                      ]),
                                    });
                                await doc.reference.delete();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => doc.reference.delete(),
                            ),
                          ],
                        )
                      : IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => doc.reference.delete(),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
