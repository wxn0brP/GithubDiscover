import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/api_service.dart';
import 'logs.dart';

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => MainViewState();
}

class MainViewState extends State<MainView> {
  String? _selectedLanguage;
  final _pageController = TextEditingController(text: "1");
  final _perPageController = TextEditingController(text: "6");
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ApiService>().loadLangData();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _perPageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("GitHub Discover"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Consumer<ApiService>(
            builder: (context, apiService, child) {
              return IconButton(
                icon: const Icon(Icons.settings),
                tooltip: "Settings",
                onPressed: apiService.langData.isEmpty && !apiService.langDataLoadError
                    ? null
                    : () => _showSettingsForm(context),
              );
            },
          ),
          Consumer<ApiService>(
            builder: (context, apiService, child) {
              return IconButton(
                icon: const Icon(Icons.history),
                tooltip: "History",
                onPressed: apiService.history.isEmpty
                    ? null
                    : () => _showHistory(context, apiService),
              );
            },
          ),
          Consumer<ApiService>(
            builder: (context, apiService, child) {
              return IconButton(
                icon: const Icon(Icons.terminal),
                tooltip: "Logs",
                onPressed: () => _showLogs(context, apiService),
              );
            },
          ),
        ],
      ),
      body: Consumer<ApiService>(
        builder: (context, apiService, child) {
          if (apiService.langDataLoadError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    "Failed to load data.\nCheck your internet connection.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text("Retry"),
                    onPressed: () => apiService.loadLangData(),
                  ),
                ],
              ),
            );
          }
          if (apiService.langData.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (apiService.currentRepos.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("Tap the button below to find repositories", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return child!;
        },
        child: ResultsList(scrollController: _scrollController),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _findRandomRepo(context),
        icon: const Icon(Icons.search),
        label: const Text("Find"),
      ),
    );
  }

  void _showSettingsForm(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Align(
          alignment: Alignment.topCenter,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 24,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Settings",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedLanguage ?? "all",
                    decoration: const InputDecoration(
                      labelText: "Language",
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: "all",
                        child: Text("All languages"),
                      ),
                      ...context.read<ApiService>().availableLanguages.map((lang) {
                        return DropdownMenuItem(value: lang, child: Text(lang));
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedLanguage = value == "all" ? null : value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _pageController,
                          decoration: const InputDecoration(
                            labelText: "Page",
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _perPageController,
                          decoration: const InputDecoration(
                            labelText: "Per Page",
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    child: const Text("Done"),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _findRandomRepo(BuildContext context) async {
    final apiService = context.read<ApiService>();
    final page = int.tryParse(_pageController.text) ?? 1;
    final perPage = int.tryParse(_perPageController.text) ?? 6;

    try {
      await apiService.findRandomRepo(
        language: _selectedLanguage,
        page: page,
        perPage: perPage,
      );
      if (mounted) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Found repositories!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showHistory(BuildContext context, ApiService apiService) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        children: [
          ListTile(
            title: const Text("History"),
            trailing: IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () {
                apiService.clearHistory();
                Navigator.pop(context);
              },
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: apiService.history.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    apiService.history[apiService.history.length - 1 - index],
                  ),
                  dense: true,
                  onTap: () => _openRepoUrl(
                    apiService.history[apiService.history.length - 1 - index],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showLogs(BuildContext context, ApiService apiService) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => LogsBottomSheet(apiService: apiService),
    );
  }

  Future<void> _openRepoUrl(String fullName) async {
    final uri = Uri.parse("https://github.com/$fullName");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class ResultsList extends StatelessWidget {
  final ScrollController scrollController;

  const ResultsList({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Consumer<ApiService>(
      builder: (context, apiService, child) {
        final repos = apiService.currentRepos;
        return ListView.builder(
          controller: scrollController,
          itemCount: repos.length,
          itemBuilder: (context, index) {
            final repo = repos[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ListTile(
                title: Text(
                  repo.fullName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (repo.description != null &&
                        repo.description!.isNotEmpty)
                      Text(repo.description!)
                    else
                      const Text("No description"),
                    const SizedBox(height: 4),
                    Text("⭐ ${repo.stargazersCount} | 🍴 ${repo.forksCount}"),
                    Text("Language: ${repo.language ?? "-"}"),
                    Text("Updated: ${_formatDate(repo.updatedAt)}"),
                  ],
                ),
                isThreeLine: true,
                onTap: () => _openUrl(repo.htmlUrl),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
