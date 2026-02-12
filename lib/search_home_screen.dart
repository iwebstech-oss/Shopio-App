import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'search_results_screen.dart';

class SearchHomeScreen extends StatefulWidget {
  const SearchHomeScreen({super.key});

  @override
  State<SearchHomeScreen> createState() => _SearchHomeScreenState();
}

class _SearchHomeScreenState extends State<SearchHomeScreen> {
  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase.instance.ref();
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  List<String> _recentSearches = [];
  bool _isLoading = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final event = await _database
          .child('users')
          .child(user.uid)
          .child('recentSearches')
          .once();

      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final searches = data.values
            .map((e) => e.toString())
            .toList()
            .cast<String>()
            .reversed
            .toList();

        if (mounted) {
          setState(() {
            _recentSearches = searches
                .take(10)
                .toList(); // Show last 10 searches
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading recent searches: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSearch(String query) async {
    if (query.trim().isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final searchesRef = _database
          .child('users')
          .child(user.uid)
          .child('recentSearches');

      // Get current searches
      final event = await searchesRef.once();
      Map<dynamic, dynamic> currentSearches = {};

      if (event.snapshot.value != null) {
        currentSearches = Map<dynamic, dynamic>.from(
          event.snapshot.value as Map,
        );
      }

      // Remove if already exists
      currentSearches.removeWhere((key, value) => value == query);

      // Add new search at the end
      await searchesRef.push().set(query);

      // Keep only last 20 searches
      if (currentSearches.length >= 20) {
        final keysToRemove = currentSearches.keys.take(
          currentSearches.length - 19,
        );
        for (final key in keysToRemove) {
          await searchesRef.child(key).remove();
        }
      }

      // Reload recent searches
      await _loadRecentSearches();
    } catch (e) {
      debugPrint('Error saving search: $e');
    }
  }

  void _onSearchSubmitted(String query) {
    if (query.trim().isEmpty) return;

    _saveSearch(query);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsScreen(searchQuery: query),
      ),
    );
  }

  void _onSearchChanged(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
    });

    // Don't auto-search on typing, only when user submits or taps search
  }

  void _onRecentSearchTapped(String searchQuery) {
    _searchController.text = searchQuery;
    _onSearchSubmitted(searchQuery);
  }

  Future<void> _clearRecentSearches() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _database
          .child('users')
          .child(user.uid)
          .child('recentSearches')
          .remove();

      if (mounted) {
        setState(() {
          _recentSearches = [];
        });
      }
    } catch (e) {
      debugPrint('Error clearing recent searches: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_focusNode.hasFocus) {
          _focusNode.unfocus();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: Container(
            height: 48,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F4),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 16, right: 8),
                  child: Icon(Icons.search, color: Color(0xFF5F6368), size: 22),
                ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onSubmitted: _onSearchSubmitted,
                    focusNode: _focusNode,
                    autofocus: true,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                    decoration: const InputDecoration(
                      hintText: 'Search',
                      hintStyle: TextStyle(
                        color: Color(0xFF5F6368),
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: _isSearching
            ? const SizedBox() // When searching, don't show recent searches
            : _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _recentSearches.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No recent searches',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        TextButton(
                          onPressed: _clearRecentSearches,
                          child: const Text(
                            'Clear All',
                            style: TextStyle(color: Colors.black, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _recentSearches.length,
                      itemBuilder: (context, index) {
                        final searchQuery = _recentSearches[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.history,
                              color: Colors.grey,
                              size: 20,
                            ),
                            title: Text(
                              searchQuery,
                              style: const TextStyle(fontSize: 16),
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey,
                            ),
                            onTap: () => _onRecentSearchTapped(searchQuery),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
