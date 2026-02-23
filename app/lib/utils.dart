import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart' as dif;
import 'package:shared_preferences/shared_preferences.dart' as shp;
import 'package:uuid/uuid.dart';

class DeviceIdManager {
  static const _key = "device_id";

  static Future<String> getDeviceId() async {
    final prefs = await shp.SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) return saved;

    final deviceInfo = dif.DeviceInfoPlugin();
    String newId;

    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      newId = info.id;
      if (newId.isEmpty) newId = const Uuid().v4();
    } else if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      final vendorId = info.identifierForVendor;
      newId = vendorId != null && vendorId.isNotEmpty
          ? vendorId
          : const Uuid().v4();
    } else {
      newId = const Uuid().v4();
    }

    await prefs.setString(_key, newId);
    return newId;
  }
}
