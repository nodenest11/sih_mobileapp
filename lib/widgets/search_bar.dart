import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import '../services/api_service.dart';

class SearchBar extends StatefulWidget {
  final Function(LatLng location, String name) onLocationSelected;
  final String? hintText;

  const SearchBar({
    super.key,
    required this.onLocationSelected,
    this.hintText,
  });

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  final TextEditingController _controller = TextEditingController();
  late final ApiService _apiService;
  
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  bool _showResults = false;
  Timer? _debounceTimer;
  
  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showResults = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _showResults = true;
    });

    try {
      final results = await _apiService.searchLocation(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _onSearchChanged(String value) {
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    // Create new timer for debouncing
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted && _controller.text == value) {
        _searchLocation(value);
      }
    });
  }

  void _selectLocation(Map<String, dynamic> location) {
    final latLng = LatLng(location['lat'], location['lon']);
    final name = location['display_name'];
    
    _controller.text = name;
    setState(() {
      _showResults = false;
    });
    
    widget.onLocationSelected(latLng, name);
  }

  void _clearSearch() {
    _controller.clear();
    _debounceTimer?.cancel();
    setState(() {
      _searchResults = [];
      _showResults = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchField(),
        if (_showResults) _buildSearchResults(),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: widget.hintText ?? 'Search for a location...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  onPressed: _clearSearch,
                  icon: const Icon(Icons.clear, color: Colors.grey),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _isLoading
          ? const _LoadingWidget()
          : _searchResults.isEmpty
              ? const _NoResultsWidget()
              : _SearchResultsList(
                  results: _searchResults.take(5).toList(),
                  onLocationSelected: _selectLocation,
                ),
    );
  }
}

// Optimized loading widget
class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

// Optimized no results widget
class _NoResultsWidget extends StatelessWidget {
  const _NoResultsWidget();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'No results found',
        style: TextStyle(color: Colors.grey),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// Optimized results list widget
class _SearchResultsList extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  final Function(Map<String, dynamic>) onLocationSelected;

  const _SearchResultsList({
    required this.results,
    required this.onLocationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        return _SearchResultTile(
          result: result,
          onTap: () => onLocationSelected(result),
        );
      },
    );
  }
}

// Optimized result tile widget
class _SearchResultTile extends StatelessWidget {
  final Map<String, dynamic> result;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.result,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(
        Icons.location_on,
        color: Colors.blue,
        size: 20,
      ),
      title: Text(
        result['display_name'],
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      onTap: onTap,
      dense: true,
    );
  }
}

// Simplified search delegate for better performance
class LocationSearchDelegate extends SearchDelegate<LatLng?> {
  late final ApiService _apiService;

  LocationSearchDelegate() {
    _apiService = ApiService();
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () => query = '',
        icon: const Icon(Icons.clear),
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return const Center(
        child: Text('Enter a location to search'),
      );
    }
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _apiService.searchLocation(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final results = snapshot.data ?? [];
        if (results.isEmpty) {
          return const Center(
            child: Text('No results found'),
          );
        }

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final result = results[index];
            return ListTile(
              leading: const Icon(Icons.location_on),
              title: Text(
                result['display_name'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                final latLng = LatLng(result['lat'], result['lon']);
                close(context, latLng);
              },
            );
          },
        );
      },
    );
  }
}
