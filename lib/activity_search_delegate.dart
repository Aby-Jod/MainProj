import 'package:flutter/material.dart';

class ActivitySearchDelegate extends SearchDelegate {
  @override
  List<Widget> buildActions(BuildContext context) {
    // Actions for the app bar (e.g., a clear button)
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    // Leading icon for the app bar (e.g., a back button)
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    // Results to show when the user submits a search
    return Center(
      child: Text(
        'Results for "$query"',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // Suggestions to show when the user is typing
    final suggestions = query.isEmpty
        ? []
        : [
            'Sample Suggestion 1',
            'Sample Suggestion 2',
            'Sample Suggestion 3',
          ].where((suggestion) => suggestion.contains(query)).toList();

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        return ListTile(
          title: Text(
            suggestion,
            style: const TextStyle(color: Colors.white),
          ),
          onTap: () {
            query = suggestion;
            showResults(context); // Show results when a suggestion is tapped
          },
        );
      },
    );
  }
}
