import 'package:shared_preferences/shared_preferences.dart' as shp;
import 'package:uuid/uuid.dart';

class AnonymousIdManager {
  static const _key = "anonymous_id";

  static Future<String> getAnonymousId() async {
    final prefs = await shp.SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) return saved;

    final newId = const Uuid().v4();
    await prefs.setString(_key, newId);
    return newId;
  }
}
