import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:badges/badges.dart' as badges;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import 'home.dart';
import 'lessons.dart';
import 'community.dart';
import 'posts.dart';
import 'settings.dart';
import 'profile.dart';
import 'notifications.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _idx = 0;
  final List<Widget> _pages = const [
    HomePage(key: ValueKey('home')),
    LessonsPage(key: ValueKey('lessons')),
    CommunityPage(key: ValueKey('community')),
    PostsPage(key: ValueKey('posts')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Icon(
              Icons.cast_for_education,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Text('الدليل التعليمي', style: TextStyle(fontFamily: 'ArR')),
          ],
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: currentUser.value != null
                ? FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser.value!.id)
                      .collection('notifications')
                      .where('read', isEqualTo: false)
                      .snapshots()
                : const Stream.empty(),
            builder: (ctx, snap) {
              int c = snap.hasData ? snap.data!.docs.length : 0;
              return IconButton(
                icon: badges.Badge(
                  showBadge: c > 0,
                  badgeContent: Text(
                    '$c',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                  child: const Icon(Icons.notifications_outlined),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                ),
              );
            },
          ),
          IconButton(
            icon: CircleAvatar(
              radius: 14,
              backgroundImage: currentUser.value?.photoUrl != null
                  ? NetworkImage(currentUser.value!.photoUrl!)
                  : null,
              child: currentUser.value?.photoUrl == null
                  ? const Icon(Icons.person, size: 16)
                  : null,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: PageTransitionSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim, secAnim) => FadeThroughTransition(
          animation: anim,
          secondaryAnimation: secAnim,
          child: child,
        ),
        child: _pages[_idx],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.class_outlined),
            selectedIcon: Icon(Icons.class_),
            label: 'الدروس',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'المجتمع',
          ),
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article),
            label: 'المنتدى',
          ),
        ],
      ),
    );
  }
}
