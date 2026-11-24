import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:simple_real_time_ride_tracking_app/models/trip_models.dart';
import 'package:simple_real_time_ride_tracking_app/services/nominatim_service.dart';

/// Modal bottom sheet for searching a destination via Nominatim geocoding.
class LocationSearchSheet extends StatefulWidget {
  const LocationSearchSheet({super.key});

  @override
  State<LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<LocationSearchSheet> {
  final _controller = TextEditingController();
  final _suggestions = <PlaceSuggestion>[];
  bool _isSearching = false;
  String? _error;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    setState(() {
      _error = null;
      if (query.trim().isEmpty) {
        _suggestions.clear();
      }
    });
    if (query.trim().isNotEmpty) {
      _debounce = Timer(const Duration(milliseconds: 600), () => _search(query));
    }
  }

  Future<void> _search(String query) async {
    setState(() => _isSearching = true);
    final results = await NominatimService.search(query);
    if (!mounted) return;
    setState(() {
      _isSearching = false;
      _suggestions
        ..clear()
        ..addAll(results);
      if (results.isEmpty) {
        _error = 'No places found.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (_, sheetController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Search Destination',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'E.g. Gulshan, Dhaka',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(_controller.text),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(color: Colors.red[700], fontSize: 13)),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: _suggestions.isEmpty &&
                      _controller.text.isNotEmpty &&
                      !_isSearching
                  ? const Center(child: Text('No results'))
                  : ListView.builder(
                      controller: sheetController,
                      itemCount: _suggestions.length,
                      itemBuilder: (_, i) {
                        final suggestion = _suggestions[i];
                        return ListTile(
                          leading: const Icon(Icons.location_city,
                              color: Colors.blue),
                          title: Text(suggestion.displayName,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: suggestion.address != null
                              ? Text(suggestion.address!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 12))
                              : null,
                          onTap: () => Navigator.pop(context, suggestion),
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