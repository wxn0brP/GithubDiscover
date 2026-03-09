import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'logs.dart';

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => MainViewState();
}

class MainViewState extends State<MainView> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedLanguage;
  final _pageController = TextEditingController(text: "1");
  final _perPageController = TextEditingController(text: "1");

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
                icon: const Icon(Icons.terminal),
                tooltip: "Logs",
                onPressed: () => _showLogs(context, apiService),
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
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Language selector
              DropdownButtonFormField<String>(
                initialValue: _selectedLanguage,
                decoration: const InputDecoration(
                  labelText: "Language",
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: "all",
                    child: Text("All languages"),
                  ),
                  ...context.watch<ApiService>().availableLanguages.map((lang) {
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

              // Page and per page inputs
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
              const SizedBox(height: 24),

              // Find button
              ElevatedButton.icon(
                icon: const Icon(Icons.search),
                label: const Text("Find Random Repo"),
                onPressed: context.watch<ApiService>().langData.isEmpty
                    ? null
                    : () => _findRandomRepo(context),
              ),
              const SizedBox(height: 24),

              // Results
              Expanded(
                child: Consumer<ApiService>(
                  builder: (context, apiService, child) {
                    if (apiService.langData.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (apiService.currentRepos.isEmpty) {
                      return const Center(
                        child: Text("Press the button to find repositories"),
                      );
                    }
                    return child!;
                  },
                  child: const ResultsList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _findRandomRepo(BuildContext context) async {
    final apiService = context.read<ApiService>();
    final page = int.tryParse(_pageController.text) ?? 1;
    final perPage = int.tryParse(_perPageController.text) ?? 10;

    try {
      await apiService.findRandomRepo(
        language: _selectedLanguage,
        page: page,
        perPage: perPage,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Found repositories!")));
      }
    } catch (e) {
      if (context.mounted) {
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
  const ResultsList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ApiService>(
      builder: (context, apiService, child) {
        final repos = apiService.currentRepos;
        return ListView.builder(
          itemCount: repos.length,
          itemBuilder: (context, index) {
            final repo = repos[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
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
