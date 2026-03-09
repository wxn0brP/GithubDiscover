import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/word.dart';
import '../models/repo.dart';

class Config {
  static const String wordsApi = "https://random-words-api.kushcreates.com/api";
  static const String githubApi = "https://api.github.com/search/repositories";
  static const String historyKey = "repo_history";
}

class ApiService extends ChangeNotifier {
  List<Word> _langData = [];
  List<Repo> _currentRepos = [];
  final List<String> _history = [];

  List<Word> get langData => _langData;
  List<Repo> get currentRepos => _currentRepos;
  List<String> get history => List.unmodifiable(_history);

  List<String> get availableLanguages {
    final langs = <String>{};
    for (final word in _langData) {
      langs.add(word.language.toLowerCase());
    }
    return langs.toList()..sort();
  }

  Future<void> loadLangData() async {
    final response = await http.get(Uri.parse(Config.wordsApi));
    if (response.statusCode != 200) {
      throw Exception("Failed to load words data");
    }
    final List<dynamic> jsonList = json.decode(response.body);
    _langData = jsonList.map((e) => Word.fromJson(e)).toList();
    await _loadHistory();
    notifyListeners();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(Config.historyKey);
    if (historyJson != null) {
      final List<dynamic> decoded = json.decode(historyJson);
      _history.clear();
      _history.addAll(decoded.map((e) => e as String));
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Config.historyKey, json.encode(_history));
  }

  Word _getRandomWord(String? language) {
    final filtered = language == null || language == "all"
        ? _langData
        : _langData
              .where((w) => w.language.toLowerCase() == language.toLowerCase())
              .toList();

    if (filtered.isEmpty) {
      throw Exception("No words found for \"$language\"");
    }

    return filtered[Random().nextInt(filtered.length)];
  }

  Future<List<Repo>> findRandomRepo({
    String? language,
    int page = 1,
    int perPage = 10,
  }) async {
    final randomWord = _getRandomWord(language);

    final uri = Uri.parse(Config.githubApi).replace(
      queryParameters: {
        "q": randomWord.word,
        "per_page": perPage.toString(),
        "page": page.toString(),
      },
    );

    final response = await http.get(
      uri,
      headers: {"Accept": "application/vnd.github.v3+json"},
    );

    if (response.statusCode == 403) {
      throw Exception("⚠️ Rate limit exceeded. Please try again later.");
    }
    if (response.statusCode != 200) {
      throw Exception("GitHub API: ${response.statusCode}");
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final items = json["items"] as List<dynamic>?;

    if (items == null || items.isEmpty) {
      throw Exception(
        "No results for \"${randomWord.word}\" on page #$page. Please try again!",
      );
    }

    _currentRepos = items.map((e) => Repo.fromJson(e)).toList();

    // Save to history
    for (final repo in _currentRepos) {
      _history.add(repo.fullName);
    }
    await _saveHistory();

    notifyListeners();
    return _currentRepos;
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _saveHistory();
    notifyListeners();
  }

  Future<void> removeHistoryItem(String fullName) async {
    _history.remove(fullName);
    await _saveHistory();
    notifyListeners();
  }
}
