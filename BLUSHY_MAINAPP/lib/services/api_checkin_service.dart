import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_base_url.dart';
import 'auth_storage.dart';

class ApiCheckinService {
  static final ApiCheckinService _instance = ApiCheckinService._internal();
  factory ApiCheckinService() => _instance;
  ApiCheckinService._internal();

  Map<String, String> _headers() {
    final token = AuthStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<bool> submitDailyCheckin({
    required String logDate,
    String? mood,
    String? energyLevel,
    int? sleepHours,
    List<String>? symptoms,
    String? notes,
    String source = 'manual_checkin',
  }) async {
    try {
      final url = Uri.parse('${resolveApiBaseUrl()}/api/checkins');
      final payload = {
        'logDate': logDate,
        if (mood != null) 'mood': mood,
        if (energyLevel != null) 'energyLevel': energyLevel,
        if (sleepHours != null) 'sleepHours': sleepHours,
        if (symptoms != null) 'symptoms': symptoms,
        if (notes != null) 'notes': notes,
        'source': source,
      };

      final response = await http.post(
        url,
        headers: _headers(),
        body: jsonEncode(payload),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
