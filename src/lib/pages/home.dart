import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final String _apiKey = "AIzaSyA12SNG4YUXFehW7eu-vmhBRYQHhB9rs9o";
  final String _primId = "UCnxju7_Ug6VbC6en6tBL6Aw";
  final String _secId = "UCZ-g-5yYrEI7KCLIDZAEF-w";

  List<dynamic> _primVideos = [];
  List<dynamic> _secVideos = [];
  String? _primToken;
  String? _secToken;
  bool _isLoading = true;
  final ScrollController _primScroll = ScrollController();
  final ScrollController _secScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _primScroll.addListener(() {
      if (_primScroll.position.pixels >=
          _primScroll.position.maxScrollExtent * 0.9)
        _loadMore(_primId, true);
    });
    _secScroll.addListener(() {
      if (_secScroll.position.pixels >=
          _secScroll.position.maxScrollExtent * 0.9)
        _loadMore(_secId, false);
    });
  }

  Future<void> _loadInitial() async {
    await Future.wait([_loadMore(_primId, true), _loadMore(_secId, false)]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadMore(String channelId, bool isPrim) async {
    String? token = isPrim ? _primToken : _secToken;
    if (token == 'END') return;

    String url =
        "https://www.googleapis.com/youtube/v3/search?key=$_apiKey&channelId=$channelId&part=snippet,id&order=date&maxResults=10&type=video";
    if (token != null) url += "&pageToken=$token";

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) {
          setState(() {
            if (isPrim) {
              _primVideos.addAll(data['items']);
              _primToken = data['nextPageToken'] ?? 'END';
            } else {
              _secVideos.addAll(data['items']);
              _secToken = data['nextPageToken'] ?? 'END';
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _openVideo(String id) async {
    final url = Uri.parse("https://www.youtube.com/watch?v=$id");
    if (await canLaunchUrl(url))
      await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ValueListenableBuilder(
                  valueListenable: currentUser,
                  builder: (_, user, __) => Text(
                    "أهلاً، ${user?.displayName?.split(' ')[0] ?? 'زائر'}",
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ),
                const Text(
                  "منصة مدرستنا",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                const Text(
                  "التعليم الأساسي",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(
                  height: 240,
                  child: _buildList(_primVideos, _primScroll),
                ),
                const SizedBox(height: 20),
                const Text(
                  "التعليم الثانوي",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(
                  height: 240,
                  child: _buildList(_secVideos, _secScroll),
                ),
              ],
            ),
    );
  }

  Widget _buildList(List videos, ScrollController controller) {
    return ListView.builder(
      controller: controller,
      scrollDirection: Axis.horizontal,
      itemCount: videos.length + 1,
      itemBuilder: (context, index) {
        if (index == videos.length)
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ),
          );
        final v = videos[index];
        return GestureDetector(
          onTap: () => _openVideo(v['id']['videoId']),
          child: Container(
            width: 280,
            margin: const EdgeInsets.only(right: 16, bottom: 8),
            child: Card(
              child: Column(
                children: [
                  Expanded(
                    child: Image.network(
                      v['snippet']['thumbnails']['high']['url'],
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      v['snippet']['title'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
