import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as path;
import 'package:timezone/data/latest.dart' as tz;
import '../utils/app_logger.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static const String _channelId = 'conversion_channel';
  static const String _channelName = 'Conversion Status';
  static const String _channelDescription =
      'Shows conversion progress and status';

  late FlutterLocalNotificationsPlugin _notifications;
  Function(String?)? _onNotificationTapped;

  NotificationService._internal();

  factory NotificationService() => _instance;

  void setOnNotificationTapped(Function(String?)? callback) {
    _onNotificationTapped = callback;
  }

  Future<void> initialize() async {
    try {
      AppLogger.debug('Menginisialisasi notifikasi...');
      _notifications = FlutterLocalNotificationsPlugin();
      tz.initializeTimeZones();

      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );

      bool? initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          AppLogger.debug('Notifikasi ditekan, payload: ${response.payload}');
          _onNotificationTapped?.call(response.payload);
        },
      );

      AppLogger.debug('Inisialisasi notifikasi selesai: $initialized');

      // Create Android notification channel
      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDescription,
              importance: Importance.high,
              enableVibration: true,
              playSound: true,
            ),
          );
    } catch (e, stackTrace) {
      AppLogger.error('Gagal menginisialisasi notifikasi', e, stackTrace);
      rethrow;
    }
  }

  // Consolidate notification methods untuk mengurangi duplikasi
  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required String ticker,
    String? payload,
  }) async {
    try {
      AppLogger.debug(
        '[NOTIF] Mencoba menampilkan notifikasi - ID: $id | Channel: $_channelId | Ticker: $ticker',
      );
      AppLogger.debug(
        '[NOTIF] Detail - Judul: $title | Pesan: $body | Payload: $payload',
      );

      // Clean up the payload path if it contains any extra characters
      String? cleanPayload = payload?.trim();
      if (cleanPayload != null && cleanPayload.isNotEmpty) {
        // Remove any potential double slashes and normalize the path
        cleanPayload = cleanPayload.replaceAll(RegExp(r'/+'), '/');

        // If the path is a file URI, convert it to a regular path
        if (cleanPayload.startsWith('file://')) {
          cleanPayload = cleanPayload.substring(7);
        }

        // Make sure the path is absolute
        if (!path.isAbsolute(cleanPayload)) {
          cleanPayload =
              '/storage/emulated/0/${cleanPayload.replaceFirst(RegExp('^/'), '')}';
        }

        final file = File(cleanPayload);
        if (await file.exists()) {
          final fileDir = path.dirname(cleanPayload);
          final formattedBody =
              '''
$body
Lokasi: $fileDir
          ''';

          await _showNotificationWithDetails(
            id: id,
            title: title,
            body: formattedBody,
            ticker: ticker,
            payload: cleanPayload,
          );
          return;
        } else {
          AppLogger.warning('File not found: $cleanPayload');
        }
      }

      // Fallback to simple notification if file handling fails
      await _showNotificationWithDetails(
        id: id,
        title: title,
        body: body,
        ticker: ticker,
        payload: cleanPayload,
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error showing notification', e, stackTrace);
      // Fallback to simple notification in case of any error
      await _showNotificationWithDetails(
        id: id,
        title: title,
        body: body,
        ticker: ticker,
        payload: payload,
      );
    }
  }

  Future<void> _showNotificationWithDetails({
    required int id,
    required String title,
    required String body,
    required String ticker,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ticker: ticker,
      enableLights: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Konversi Selesai',
        htmlFormatBigText: true,
      ),
    );

    final notification = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(threadIdentifier: _channelId),
    );

    try {
      await _notifications.show(
        id,
        title,
        body,
        notification,
        payload: payload,
      );
      AppLogger.debug('[NOTIF] Notifikasi berhasil ditampilkan - ID: $id');
    } catch (e, stackTrace) {
      AppLogger.error('Gagal menampilkan notifikasi', e, stackTrace);
    }
  }

  Future<void> showCompletionNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    AppLogger.debug(
      '[NOTIF] Memanggil showCompletionNotification - ID: $id | Judul: $title | Body: $body | Payload: $payload',
    );
    try {
      await _showNotification(
        id: id,
        title: title,
        body: body,
        ticker: 'Conversion Complete',
        payload: payload,
      );
      AppLogger.debug('showCompletionNotification berhasil dipanggil');
    } catch (e, stackTrace) {
      AppLogger.error('Error di showCompletionNotification', e, stackTrace);
      rethrow;
    }
  }

  Future<void> showErrorNotification({
    required int id,
    required String title,
    required String error,
  }) async {
    AppLogger.debug(
      '[NOTIF] Memanggil showErrorNotification - ID: $id | Error: $error',
    );
    await _showNotification(
      id: id,
      title: title,
      body: 'Error: $error',
      ticker: 'Conversion Error',
    );
  }

  Future<void> cancelNotification(int id) => _notifications.cancel(id);

  Future<void> cancelAllNotifications() => _notifications.cancelAll();
}
