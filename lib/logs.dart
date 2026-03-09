import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';

class LogsBottomSheet extends StatelessWidget {
  final ApiService apiService;

  const LogsBottomSheet({super.key, required this.apiService});

  @override
  Widget build(BuildContext context) {
    return Consumer<LoggerService>(
      builder: (context, loggerService, child) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text(
                    "Logs",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: "Copy logs",
                    onPressed: () => _copyLogs(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.email),
                    tooltip: "Send via email",
                    onPressed: () => _sendEmail(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep),
                    tooltip: "Clear logs",
                    onPressed: () {
                      loggerService.clear();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Logs cleared")),
                      );
                    },
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: loggerService.logs.isEmpty
                    ? const Center(child: Text("No logs available"))
                    : ListView.builder(
                        itemCount: loggerService.logs.length,
                        itemBuilder: (context, index) {
                          final log = loggerService
                              .logs[loggerService.logs.length - 1 - index];
                          return _LogTile(log: log);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _copyLogs(BuildContext context) async {
    final logsText = apiService.logger.getLogsAsString();
    await Clipboard.setData(ClipboardData(text: logsText));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Logs copied to clipboard")));
    }
  }

  Future<void> _sendEmail(BuildContext context) async {
    final logsText = apiService.logger.getLogsAsString();
    final subject = Uri.encodeComponent("GitHub Discover - App Logs");
    final body = Uri.encodeComponent(logsText).replaceAll("+", "%20");
    final uri = Uri.parse(
      "mailto:${Config.supportEmail}?subject=$subject&body=$body",
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not launch email client"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _LogTile extends StatelessWidget {
  final LogEntry log;

  const _LogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final color = _getLogLevelColor(log.level);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  log.level.name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  log.timestamp.toString().substring(0, 19),
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (log.source != null)
            Text(
              "[${log.source}]",
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          Text(log.message, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Color _getLogLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.blue;
      case LogLevel.info:
        return Colors.green;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
    }
  }
}
