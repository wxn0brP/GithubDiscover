import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/word.dart';
import '../models/repo.dart';
import 'logger_service.dart';

class Config {
  static const String wordsApi = "https://random-words-api.kushcreates.com/api";
  static const String githubApi = "https://api.github.com/search/repositories";
  static const String historyKey = "repo_history";
  static const String supportEmail = "bugs@wxn0.xyz";
}

class ApiService extends ChangeNotifier {
  LoggerService? _logger;
  List<Word> _langData = [];
  List<Repo> _currentRepos = [];
  final List<String> _history = [];

  List<Word> get langData => _langData;
  List<Repo> get currentRepos => _currentRepos;
  List<String> get history => List.unmodifiable(_history);

  void setLogger(LoggerService logger) {
    _logger = logger;
  }

  LoggerService get logger {
    _logger ??= LoggerService();
    return _logger!;
  }

  List<String> get availableLanguages {
    final langs = <String>{};
    for (final word in _langData) {
      langs.add(word.language.toLowerCase());
    }
    return langs.toList()..sort();
  }

  Future<void> loadLangData() async {
    _logger!.info("Loading language data from API", source: "ApiService");
    final response = await http.get(Uri.parse(Config.wordsApi));
    if (response.statusCode != 200) {
      _logger!.error(
        "Failed to load words data: ${response.statusCode}",
        source: "ApiService",
      );
      throw Exception("Failed to load words data");
    }
    final List<dynamic> jsonList = json.decode(response.body);
    _langData = jsonList.map((e) => Word.fromJson(e)).toList();
    _logger!.info("Loaded ${_langData.length} words", source: "ApiService");
    await _loadHistory();
    notifyListeners();
  }

  Future<void> _loadHistory() async {
    _logger!.debug(
      "Loading history from SharedPreferences",
      source: "ApiService",
    );
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(Config.historyKey);
    if (historyJson != null) {
      final List<dynamic> decoded = json.decode(historyJson);
      _history.clear();
      _history.addAll(decoded.map((e) => e as String));
      _logger!.debug(
        "Loaded ${_history.length} history items",
        source: "ApiService",
      );
    } else {
      _logger!.debug(
        "No history found in SharedPreferences",
        source: "ApiService",
      );
    }
  }

  Future<void> _saveHistory() async {
    _logger!.debug(
      "Saving history to SharedPreferences (${_history.length} items)",
      source: "ApiService",
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Config.historyKey, json.encode(_history));
  }

  Word _getRandomWord(String? language) {
    _logger!.debug(
      "Getting random word for language: ${language ?? "all"}",
      source: "ApiService",
    );
    final filtered = language == null || language == "all"
        ? _langData
        : _langData
              .where((w) => w.language.toLowerCase() == language.toLowerCase())
              .toList();

    if (filtered.isEmpty) {
      _logger!.warning(
        "No words found for language: $language",
        source: "ApiService",
      );
      throw Exception("No words found for \"$language\"");
    }

    final randomWord = filtered[Random().nextInt(filtered.length)];
    _logger!.debug("Selected word: ${randomWord.word}", source: "ApiService");
    return randomWord;
  }

  Future<List<Repo>> findRandomRepo({
    String? language,
    int page = 1,
    int perPage = 10,
  }) async {
    _logger!.info(
      "Finding random repo (lang: ${language ?? "all"}, page: $page, perPage: $perPage)",
      source: "ApiService",
    );
    final randomWord = _getRandomWord(language);

    final uri = Uri.parse(Config.githubApi).replace(
      queryParameters: {
        "q": randomWord.word,
        "per_page": perPage.toString(),
        "page": page.toString(),
      },
    );

    _logger!.debug("GitHub API URL: $uri", source: "ApiService");
    final response = await http.get(
      uri,
      headers: {"Accept": "application/vnd.github.v3+json"},
    );

    if (response.statusCode == 403) {
      _logger!.error("Rate limit exceeded (403)", source: "ApiService");
      throw Exception("⚠️ Rate limit exceeded. Please try again later.");
    }
    if (response.statusCode != 200) {
      _logger!.error(
        "GitHub API error: ${response.statusCode}",
        source: "ApiService",
      );
      throw Exception("GitHub API: ${response.statusCode}");
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final items = json["items"] as List<dynamic>?;

    if (items == null || items.isEmpty) {
      _logger!.warning(
        "No results for word: ${randomWord.word}",
        source: "ApiService",
      );
      throw Exception(
        "No results for \"${randomWord.word}\" on page #$page. Please try again!",
      );
    }

    _currentRepos = items.map((e) => Repo.fromJson(e)).toList();
    _logger!.info(
      "Found ${_currentRepos.length} repositories",
      source: "ApiService",
    );

    // Save to history
    for (final repo in _currentRepos) {
      _history.add(repo.fullName);
    }
    await _saveHistory();

    notifyListeners();
    return _currentRepos;
  }

  Future<void> clearHistory() async {
    _logger!.info("Clearing history", source: "ApiService");
    _history.clear();
    await _saveHistory();
    notifyListeners();
  }

  Future<void> removeHistoryItem(String fullName) async {
    _logger!.debug("Removing history item: $fullName", source: "ApiService");
    _history.remove(fullName);
    await _saveHistory();
    notifyListeners();
  }
}
