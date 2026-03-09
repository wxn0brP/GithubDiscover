import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'view.dart';
import 'services/api_service.dart';
import 'services/logger_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoggerService()),
        ChangeNotifierProxyProvider<LoggerService, ApiService>(
          create: (_) => ApiService(),
          update: (context, loggerService, apiService) {
            apiService?.setLogger(loggerService);
            return apiService ?? ApiService();
          },
        ),
      ],
      child: MaterialApp(
        title: "GitHub Discover",
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
        ),
        home: const MainView(),
      ),
    );
  }
}
