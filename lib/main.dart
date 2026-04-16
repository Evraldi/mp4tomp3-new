import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'screens/main_menu_screen.dart';
import 'services/notification_service.dart';
import 'utils/app_logger.dart';

void _handleUncaughtError(Object error, StackTrace stackTrace) {
  AppLogger.error('Uncaught error', error, stackTrace);
}

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      AppLogger.info('Starting application...');

      AppLogger.verbose('Setting preferred orientations');
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      AppLogger.verbose('Initializing notification service');
      final notificationService = NotificationService();
      await notificationService.initialize();
      AppLogger.info('Notification service initialized');

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        AppLogger.error(
          'Flutter error: ${details.exception}',
          details.exception,
          details.stack,
        );
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        AppLogger.error('Platform error', error, stack);
        return true;
      };

      runApp(const MyApp());
    } catch (e, stackTrace) {
      AppLogger.error('Fatal error in main', e, stackTrace);
      rethrow;
    }
  }, _handleUncaughtError);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    AppLogger.verbose('Building MyApp');

    return MaterialApp(
      title: 'MP4 to MP3 Converter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      home: const MainMenuScreen(),
      builder: (context, child) {
        ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
          AppLogger.error(
            'Widget error',
            errorDetails.exception,
            errorDetails.stack,
          );
          return ErrorWidget(errorDetails.exception);
        };
        return child!;
      },
    );
  }
}
