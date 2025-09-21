import 'package:flutter/material.dart';

class LocationSearchBar extends StatefulWidget {
  final Function(String) onSearch;

  const LocationSearchBar({super.key, required this.onSearch});

  @override
  State<LocationSearchBar> createState() => _LocationSearchBarState();
}

class _LocationSearchBarState extends State<LocationSearchBar> {
  final TextEditingController _controller = TextEditingController();
  bool _isSearching = false;

  void _performSearch() async {
    if (_controller.text.trim().isEmpty) {
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      await widget.onSearch(_controller.text.trim());
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: 'Search for a location...',
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF1565C0),
          ),
          suffixIcon: _isSearching
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF1565C0),
                      ),
                    ),
                  ),
                )
              : IconButton(
                  onPressed: _performSearch,
                  icon: const Icon(
                    Icons.send,
                    color: Color(0xFF1565C0),
                  ),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        onSubmitted: (_) => _performSearch(),
        textInputAction: TextInputAction.search,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}