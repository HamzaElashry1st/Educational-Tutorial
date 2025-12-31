import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});
  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TabBar(
        controller: _tabs,
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Colors.grey,
        tabs: const [
          Tab(text: 'المحادثات'),
          Tab(text: 'الأصدقاء'),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [ChatsList(), FriendsList()],
      ),
    );
  }
}

class ChatsList extends StatelessWidget {
  const ChatsList({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUser.value!.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty)
          return const Center(child: Text('لا توجد محادثات'));

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (ctx, i) {
            final doc = snapshot.data!.docs[i];
            final data = doc.data() as Map<String, dynamic>;
            final otherId = (data['participants'] as List).firstWhere(
              (id) => id != currentUser.value!.id,
            );

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(otherId)
                  .get(),
              builder: (ctx, snap) {
                if (!snap.hasData) return const SizedBox();
                final name = snap.data!['name'];
                return ListTile(
                  leading: CircleAvatar(child: Text(name[0])),
                  title: Text(name),
                  subtitle: Text(data['lastMessage'] ?? ''),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        chatId: doc.id,
                        otherId: otherId,
                        name: name,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class FriendsList extends StatelessWidget {
  const FriendsList({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.value!.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final friends = List<String>.from(data['friends'] ?? []);

        if (friends.isEmpty) return const Center(child: Text('لا يوجد أصدقاء'));

        return ListView.builder(
          itemCount: friends.length,
          itemBuilder: (ctx, i) {
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(friends[i])
                  .get(),
              builder: (ctx, snap) {
                if (!snap.hasData) return const SizedBox();
                final f = snap.data!;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: f['photoUrl'] != null
                        ? NetworkImage(f['photoUrl'])
                        : null,
                  ),
                  title: Text(f['name']),
                  trailing: IconButton(
                    icon: const Icon(Icons.message),
                    onPressed: () async {
                      final q = await FirebaseFirestore.instance
                          .collection('chats')
                          .where(
                            'participants',
                            arrayContains: currentUser.value!.id,
                          )
                          .get();
                      String? chatId;
                      for (var d in q.docs) {
                        if ((d['participants'] as List).contains(f.id))
                          chatId = d.id;
                      }
                      if (chatId == null) {
                        final r = await FirebaseFirestore.instance
                            .collection('chats')
                            .add({
                              'participants': [currentUser.value!.id, f.id],
                              'lastMessage': '',
                              'timestamp': FieldValue.serverTimestamp(),
                            });
                        chatId = r.id;
                      }
                      if (context.mounted)
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatPage(
                              chatId: chatId!,
                              otherId: f.id,
                              name: f['name'],
                            ),
                          ),
                        );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class ChatPage extends StatefulWidget {
  final String chatId, otherId, name;
  const ChatPage({
    super.key,
    required this.chatId,
    required this.otherId,
    required this.name,
  });
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _ctrl = TextEditingController();
  void _send() {
    if (_ctrl.text.isEmpty) return;
    final msg = _ctrl.text;
    _ctrl.clear();
    final ts = FieldValue.serverTimestamp();
    FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({'text': msg, 'uid': currentUser.value!.id, 'ts': ts});
    FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
      'lastMessage': msg,
      'timestamp': ts,
    });
    FirebaseFirestore.instance
        .collection('users')
        .doc(widget.otherId)
        .collection('notifications')
        .add({
          'type': 'message',
          'fromId': currentUser.value!.id,
          'fromName': currentUser.value!.displayName,
          'title': 'رسالة جديدة',
          'body': msg,
          'read': false,
          'timestamp': ts,
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('ts', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final msgs = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  itemCount: msgs.length,
                  itemBuilder: (ctx, i) {
                    final d = msgs[i].data() as Map<String, dynamic>;
                    final isMe = d['uid'] == currentUser.value!.id;
                    return Align(
                      alignment: isMe
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.teal : Colors.grey[800],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          d['text'],
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(
                      hintText: 'اكتب رسالة...',
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send), onPressed: _send),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
