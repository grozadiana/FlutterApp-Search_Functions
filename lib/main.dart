import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: PhotoListScreen(),
    );
  }
}

class Photo {
  String id;
  String author;
  String imageUrl;
  String authorProfileUrl;
  String color;

  Photo({
    required this.id,
    required this.author,
    required this.imageUrl,
    required this.authorProfileUrl,
    required this.color,
  });

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['id'],
      author: json['user']['username'],
      imageUrl: json['urls']['regular'],
      authorProfileUrl: json['user']['links']['html'],
      color: json['color'],
    );
  }
}

class UnsplashApi {
  final String apiKey = 'uMMIAf8R4FdsjeGUmEKkZRjFtap0BhJU-3P9Ww8Fe_s';

  Future<List<Photo>> getPhotos({String? authorFilter, String? colorFilter, int page = 1, int perPage = 10}) async {
    String apiUrl = 'https://api.unsplash.com/photos?page=$page&per_page=$perPage';

    if (authorFilter != null && authorFilter.isNotEmpty) {
      apiUrl += '&username=$authorFilter';
    }

    final response = await http.get(
      Uri.parse(apiUrl),
      headers: {'Authorization': 'Client-ID $apiKey'},
    );

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => Photo.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load photos');
    }
  }
}

class PhotoListScreen extends StatefulWidget {
  const PhotoListScreen({Key? key}) : super(key: key);

  @override
  State<PhotoListScreen> createState() => _PhotoListScreenState();

}

class _PhotoListScreenState extends State<PhotoListScreen> {
  final UnsplashApi _unsplashApi = UnsplashApi();
  List<Photo> _allPhotos = [];
  List<Photo> _filteredPhotos = [];
  bool _isLoading = false;
  bool _hasMorePhotos = true;
  final TextEditingController _authorFilterController = TextEditingController();
  final TextEditingController _colorFilterController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _authorFilterController.addListener(_onFilterChanged);
    _colorFilterController.addListener(_onFilterChanged);
    _scrollController.addListener(_onScroll);
    _loadPhotos();
  }

  void _onFilterChanged() {
    setState(() {
      _currentPage = 1;
      _allPhotos = [];
      _filteredPhotos = [];
      _hasMorePhotos = true;
    });

    _loadPhotos();
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && !_isLoading && _hasMorePhotos) {
      _loadMorePhotos();
    }
  }

  Future<void> _loadData({bool isLoadMore = false}) async {
    if (!_isLoading && (_hasMorePhotos || isLoadMore)) {
      setState(() {
        _isLoading = true;
      });

      try {
        final List<Photo> newPhotos = await _unsplashApi.getPhotos(
          authorFilter: _authorFilterController.text,
          colorFilter: _colorFilterController.text,
          page: _currentPage,
        );

        if (newPhotos.isNotEmpty) {
          setState(() {
            _allPhotos.addAll(newPhotos);
            _filteredPhotos = _allPhotos
                .where((photo) =>
            photo.author.toLowerCase().contains(_authorFilterController.text.toLowerCase()) &&
                photo.color.toLowerCase().contains(_colorFilterController.text.toLowerCase()))
                .toList();
            if (isLoadMore) {
              _currentPage++;
            }
          });
        } else {
          setState(() {
            _hasMorePhotos = false;
          });
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPhotos() async {
    await _loadData();
  }

  Future<void> _loadMorePhotos() async {
    await _loadData(isLoadMore: true);
  }

  Future<void> _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unsplash Photos List'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _authorFilterController,
              decoration: const InputDecoration(
                labelText: 'Author Name',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _colorFilterController,
              decoration: const InputDecoration(
                labelText: 'Color',
              ),
            ),
          ),
          Expanded(
            child: _isLoading && _filteredPhotos.isEmpty
                ? const Center(
              child: CircularProgressIndicator(),
            )
                : ListView.builder(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              itemCount: _filteredPhotos.length + (_hasMorePhotos ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < _filteredPhotos.length) {
                  return ListTile(
                    title: Text(_filteredPhotos[index].author),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.network(_filteredPhotos[index].imageUrl),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () async {
                            String url = _filteredPhotos[index].authorProfileUrl;
                            await _launchUrl(url);
                          },
                          child: const Text('Author Profile'),
                        ),
                      ],
                    ),
                  );
                } else {
                  return Center(
                    child: _hasMorePhotos
                        ? const CircularProgressIndicator()
                        : const Text('No more photos available'),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
