import 'package:flutter/material.dart';
import 'package:calculator/favourite.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavouriteScreen extends StatefulWidget {
  const FavouriteScreen({super.key});

@override
  State<FavouriteScreen> createState() => _FavouriteScreenState();
}

class _FavouriteScreenState extends State<FavouriteScreen> {
  List<FavoriteItem> favorites = [];

@override
  void initState() {
    super.initState();
    _loadFavorites();
  }

Future<void> _loadFavorites() async {
    await FavoritesManager().loadFavorites();
    setState(() {
      favorites = FavoritesManager().getFavorites();
    });
  }

void _removeFavorite(String expression) async {
    await FavoritesManager().removeFavorite(expression);
    setState(() {
      favorites = FavoritesManager().getFavorites();
    });
  }
@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: favorites.isEmpty
          ? const Center(child: Text('No favorites yet'))
          : ListView.builder(
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final item = favorites[index];
                return ListTile(
                  title: Text(item.expression),
                  subtitle: Text('= ${item.result}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.star, color: Colors.amber),
                    onPressed: () => _removeFavorite(item.expression),
                  ),
                  onTap: () {
                    Navigator.pop(context, item.expression);
                  },
                );
              },
            ),
    );
  }
}



class FavoritesManager {
  static final FavoritesManager _instance = FavoritesManager._internal();
  factory FavoritesManager() => _instance;
  FavoritesManager._internal();

  final List<FavoriteItem> _favorites = [];

  Future<void> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getStringList('favorites') ?? [];
    _favorites.clear();
    
    for (final json in favoritesJson) {
      final parts = json.split('|');
      if (parts.length == 3) {
        _favorites.add(FavoriteItem(
          parts[0],
          parts[1],
          DateTime.parse(parts[2]),
        ));
      }
    }
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = _favorites.map((fav) => 
      '${fav.expression}|${fav.result}|${fav.addedOn.toIso8601String()}').toList();
    await prefs.setStringList('favorites', favoritesJson);
  }

  Future<void> addFavorite(String expression, String result) async {
    // Check if already exists
    if (!_favorites.any((fav) => fav.expression == expression)) {
      _favorites.add(FavoriteItem(expression, result, DateTime.now()));
      await _saveFavorites();
    }
  }

  Future<void> removeFavorite(String expression) async {
    _favorites.removeWhere((fav) => fav.expression == expression);
    await _saveFavorites();
  }

  List<FavoriteItem> getFavorites() => List.unmodifiable(_favorites);

  bool isFavorite(String expression) {
    return _favorites.any((fav) => fav.expression == expression);
  }
}

class FavoriteItem {
  final String expression;
  final String result;
  final DateTime addedOn;

  FavoriteItem(this.expression, this.result, this.addedOn);
}
