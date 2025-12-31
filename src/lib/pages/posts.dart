import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';

class Post {
  final String id;
  final String title;
  final String content;
  final DateTime timestamp;
  final String? authorId;
  final String? authorName;
  final String? authorPhoto;

  Post({
    required this.id,
    required this.title,
    required this.content,
    required this.timestamp,
    this.authorId,
    this.authorName,
    this.authorPhoto,
  });

  factory Post.fromMap(String id, Map<String, dynamic> data) {
    return Post(
      id: id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      authorId: data['authorId'],
      authorName: data['authorName'],
      authorPhoto: data['authorPhoto'],
    );
  }
}

class Comment {
  final String id;
  final String content;
  final DateTime timestamp;
  final String? authorId;
  final String? authorName;

  Comment({
    required this.id,
    required this.content,
    required this.timestamp,
    this.authorId,
    this.authorName,
  });

  factory Comment.fromMap(String id, Map<String, dynamic> data) {
    return Comment(
      id: id,
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      authorId: data['authorId'],
      authorName: data['authorName'],
    );
  }
}

class PostsPage extends StatefulWidget {
  const PostsPage({super.key});
  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Stream<List<Post>> _getPosts() {
    return FirebaseFirestore.instance
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Post.fromMap(doc.id, doc.data())).toList());
  }

  void _showCreatePostDialog(BuildContext context) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation1, animation2) => Container(),
      transitionBuilder: (context, a1, a2, widget) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: a1, curve: Curves.easeOutCubic)),
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 10,
            backgroundColor: Theme.of(context).dialogBackgroundColor,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: StatefulBuilder(
                builder: (context, setStateDialog) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_note_rounded,
                              color: Theme.of(context).colorScheme.primary, size: 28),
                          const SizedBox(width: 8),
                          Text(
                            'منشور جديد',
                            style: TextStyle(
                              fontFamily: 'UI',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: 'العنوان',
                          labelStyle: TextStyle(fontFamily: 'UI', color: Theme.of(context).hintColor),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        ),
                        style: const TextStyle(fontFamily: 'UI', fontWeight: FontWeight.w600),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: contentController,
                        decoration: InputDecoration(
                          labelText: 'بم تفكر؟',
                          labelStyle: TextStyle(fontFamily: 'UI', color: Theme.of(context).hintColor),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          alignLabelWithHint: true,
                        ),
                        style: const TextStyle(fontFamily: 'UI', height: 1.5),
                        maxLines: 5,
                        minLines: 3,
                        textInputAction: TextInputAction.newline,
                        textAlignVertical: TextAlignVertical.top,
                      ),
                      const SizedBox(height: 16),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: Theme.of(context).dividerColor),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Text(
                                'إلغاء',
                                style: TextStyle(
                                  fontFamily: 'UI',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () async {
                                final title = titleController.text.trim();
                                final content = contentController.text.trim();
                                if (title.isNotEmpty && content.isNotEmpty && currentUser.value != null) {
                                  await FirebaseFirestore.instance.collection('posts').add({
                                    'title': title,
                                    'content': content,
                                    'timestamp': DateTime.now(),
                                    'authorId': currentUser.value!.id,
                                    'authorName': currentUser.value!.displayName,
                                    'authorPhoto': currentUser.value!.photoUrl,
                                  });
                                  Navigator.pop(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text(
                                'نشر الآن',
                                style: TextStyle(fontFamily: 'UI', fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCommentsSheet(BuildContext context, String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: CommentSheet(postId: postId),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: StreamBuilder<List<Post>>(
        stream: _getPosts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('لا توجد منشورات حالياً', style: TextStyle(fontFamily: 'UI')),
            );
          }
          final posts = snapshot.data!;
          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return Dismissible(
                key: ValueKey(post.id),
                direction: post.authorId == currentUser.value?.id
                    ? DismissDirection.endToStart
                    : DismissDirection.none,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  color: Colors.red.withOpacity(0.1),
                  child: const Icon(Icons.delete, color: Colors.red),
                ),
                confirmDismiss: (dir) async {
                  if (post.authorId == currentUser.value?.id) {
                    await FirebaseFirestore.instance.collection('posts').doc(post.id).delete();
                  }
                  return false;
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: post.authorPhoto != null ? NetworkImage(post.authorPhoto!) : null,
                              backgroundColor: post.authorPhoto == null
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                              child: post.authorPhoto == null
                                  ? const Icon(Icons.person, size: 20, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              post.authorName?.isNotEmpty == true ? post.authorName! : '[محذوف]',
                              style: const TextStyle(fontFamily: 'UI', fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${post.timestamp.day.toString().padLeft(2, '0')}/${post.timestamp.month.toString().padLeft(2, '0')}/${post.timestamp.year}',
                                  style: const TextStyle(fontFamily: 'UI', fontSize: 12),
                                ),
                                Text(
                                  '${post.timestamp.hour.toString().padLeft(2, '0')}:${post.timestamp.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontFamily: 'UI', fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(post.title,
                            style: const TextStyle(
                                fontFamily: 'UI', fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(post.content, style: const TextStyle(fontFamily: 'UI')),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () => _showCommentsSheet(context, post.id),
                              icon: const Icon(Icons.comment, size: 16),
                              label: const Text('عرض التعليقات', style: TextStyle(fontFamily: 'UI')),
                              style: TextButton.styleFrom(padding: EdgeInsets.zero),
                            ),
                            const Spacer(),
                            if (post.authorId == currentUser.value?.id)
                              TextButton.icon(
                                onPressed: () async {
                                  await FirebaseFirestore.instance.collection('posts').doc(post.id).delete();
                                },
                                icon: const Icon(Icons.delete, size: 16),
                                label: const Text('حذف', style: TextStyle(fontFamily: 'UI')),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreatePostDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class CommentSheet extends StatefulWidget {
  final String postId;
  const CommentSheet({super.key, required this.postId});
  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _inputScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_inputScrollController.hasClients) {
          _inputScrollController.jumpTo(_inputScrollController.position.maxScrollExtent);
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputScrollController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final content = _controller.text.trim();
    if (content.isNotEmpty && currentUser.value != null) {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
        'content': content,
        'timestamp': DateTime.now(),
        'authorId': currentUser.value!.id,
        'authorName': currentUser.value!.displayName,
      });
      _controller.clear();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('التعليقات', style: TextStyle(fontFamily: 'UI', fontSize: 18)),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                final comments = snapshot.data!.docs
                    .map((doc) => Comment.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                    .toList();
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return Dismissible(
                      key: ValueKey(comment.id),
                      direction: comment.authorId == currentUser.value?.id
                          ? DismissDirection.endToStart
                          : DismissDirection.none,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        color: Colors.red.withOpacity(0.1),
                        child: const Icon(Icons.delete, color: Colors.red),
                      ),
                      confirmDismiss: (dir) async {
                        if (comment.authorId == currentUser.value?.id) {
                          await FirebaseFirestore.instance
                              .collection('posts')
                              .doc(widget.postId)
                              .collection('comments')
                              .doc(comment.id)
                              .delete();
                        }
                        return false;
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundImage: null,
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    child: const Icon(Icons.person, size: 18, color: Colors.white),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    comment.authorName?.isNotEmpty == true ? comment.authorName! : '[محذوف]',
                                    style: const TextStyle(fontFamily: 'UI', fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${comment.timestamp.day.toString().padLeft(2, '0')}/${comment.timestamp.month.toString().padLeft(2, '0')}/${comment.timestamp.year}',
                                        style: const TextStyle(fontFamily: 'UI', fontSize: 12),
                                      ),
                                      Text(
                                        '${comment.timestamp.hour.toString().padLeft(2, '0')}:${comment.timestamp.minute.toString().padLeft(2, '0')}',
                                        style: const TextStyle(fontFamily: 'UI', fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(comment.content, style: const TextStyle(fontFamily: 'UI')),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              scrollController: _inputScrollController,
              decoration: const InputDecoration(
                hintText: 'أضف تعليقًا',
                hintStyle: TextStyle(fontFamily: 'UI'),
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontFamily: 'UI'),
              maxLines: 5,
              minLines: 1,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              textAlignVertical: TextAlignVertical.top,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitComment,
                child: const Text('إرسال', style: TextStyle(fontFamily: 'UI')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
