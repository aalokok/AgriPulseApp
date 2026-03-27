import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../config/constants.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == AppConstants.backgroundTaskName) {
      await _performWaterLevelCheck();
    }
    return true;
  });
}

Future<void> _performWaterLevelCheck() async {
  try {
    const storage = FlutterSecureStorage();
    final serverUrl = await storage.read(key: AppConstants.keyServerUrl);
    final accessToken = await storage.read(key: AppConstants.keyAccessToken);
    final refreshToken = await storage.read(key: AppConstants.keyRefreshToken);

    if (serverUrl == null || accessToken == null) return;

    final prefs = await SharedPreferences.getInstance();
    final threshold = prefs.getDouble(AppConstants.keyThreshold) ??
        AppConstants.defaultWaterLevelThreshold;
    final notificationsEnabled =
        prefs.getBool(AppConstants.keyNotificationsEnabled) ?? true;

    if (!notificationsEnabled) return;

    final dio = Dio();
    Response response;
    try {
      response = await dio.get(
        '$serverUrl/api/log/water_level',
        queryParameters: {'sort': '-timestamp', 'page[limit]': '1'},
        options: Options(headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/vnd.api+json',
        }),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 && refreshToken != null) {
        final tokenResponse = await dio.post(
          '$serverUrl/oauth/token',
          data: {
            'grant_type': 'refresh_token',
            'client_id': AppConstants.oauthClientId,
            'refresh_token': refreshToken,
          },
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
        final newAccess = tokenResponse.data['access_token'] as String;
        final newRefresh = tokenResponse.data['refresh_token'] as String;
        final expiresIn = tokenResponse.data['expires_in'] as int? ?? 300;
        final expiry = DateTime.now().add(Duration(seconds: expiresIn));

        await storage.write(
            key: AppConstants.keyAccessToken, value: newAccess);
        await storage.write(
            key: AppConstants.keyRefreshToken, value: newRefresh);
        await storage.write(
            key: AppConstants.keyTokenExpiry,
            value: expiry.toIso8601String());

        response = await dio.get(
          '$serverUrl/api/log/water_level',
          queryParameters: {'sort': '-timestamp', 'page[limit]': '1'},
          options: Options(headers: {
            'Authorization': 'Bearer $newAccess',
            'Accept': 'application/vnd.api+json',
          }),
        );
      } else {
        rethrow;
      }
    }

    final data = response.data['data'] as List?;
    if (data == null || data.isEmpty) return;

    final attributes = data.first['attributes'] as Map<String, dynamic>;
    final quantities = attributes['quantity'] as List?;
    if (quantities == null || quantities.isEmpty) return;

    final rawVal = quantities.first['value'];
    final waterLevel = rawVal is num
        ? rawVal.toDouble()
        : double.tryParse(rawVal.toString()) ?? 0;
    final units = quantities.first['units'] as String? ?? 'cm';

    final notifService = NotificationService();
    await notifService.init();

    if (waterLevel < threshold) {
      await notifService.showThresholdAlert(
        valueCm: waterLevel,
        thresholdCm: threshold,
        units: units,
      );
    } else {
      await notifService.showReadingNotification(
        valueCm: waterLevel,
        units: units,
      );
    }
  } catch (_) {
    // Silently fail in background
  }
}

class BackgroundService {
  Future<void> init() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  Future<void> registerPeriodicTask() async {
    await Workmanager().registerPeriodicTask(
      AppConstants.backgroundTaskTag,
      AppConstants.backgroundTaskName,
      frequency: AppConstants.backgroundSyncInterval,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  Future<void> cancelAll() async {
    await Workmanager().cancelAll();
  }
}
