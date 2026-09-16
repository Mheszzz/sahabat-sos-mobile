import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';
import '../../../../core/constants/api_constants.dart';
import 'package:image_picker/image_picker.dart';

abstract class ProfileRemoteDataSource {
  Future<Map<String, dynamic>> getProfile();
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data);
  Future<Map<String, dynamic>> updateProfileWithFoto(Map<String, dynamic> data, XFile imageFile);
  Future<Map<String, dynamic>> uploadFoto(XFile imageFile);
  Future<Map<String, dynamic>> deleteFoto();
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final SharedPreferences prefs;

  ProfileRemoteDataSourceImpl({required this.prefs});

  Map<String, String> _getHeaders() {
    final token = prefs.getString('auth_token');
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  MediaType _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return MediaType('image', 'png');
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'webp':
        return MediaType('image', 'webp');
      default:
        return MediaType('image', 'jpeg');
    }
  }

  @override
  Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse(ApiConstants.profile),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Gagal mengambil profil. Status: ${response.statusCode}');
    }
  }

  @override
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse(ApiConstants.profile),
      headers: _getHeaders(),
      body: json.encode(data),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Gagal memperbarui profil. Status: ${response.statusCode}');
    }
  }

  @override
  Future<Map<String, dynamic>> updateProfileWithFoto(Map<String, dynamic> data, XFile imageFile) async {
    var request = http.MultipartRequest('POST', Uri.parse(ApiConstants.profile));
    
    // Add headers
    request.headers.addAll({
      'Authorization': 'Bearer ${prefs.getString('auth_token')}',
      'Accept': 'application/json',
    });

    // Add string fields
    data.forEach((key, value) {
      request.fields[key] = value.toString();
    });

    // Add file with correct field name and MIME type
    final bytes = await imageFile.readAsBytes();
    final mimeType = _getMimeType(imageFile.name);
    request.files.add(http.MultipartFile.fromBytes(
      'foto_profile', 
      bytes,
      filename: imageFile.name,
      contentType: mimeType,
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Gagal memperbarui profil dan foto. Status: ${response.statusCode}');
    }
  }

  @override
  Future<Map<String, dynamic>> uploadFoto(XFile imageFile) async {
    var request = http.MultipartRequest('POST', Uri.parse(ApiConstants.profileFoto));
    
    // Add headers
    request.headers.addAll({
      'Authorization': 'Bearer ${prefs.getString('auth_token')}',
      'Accept': 'application/json',
    });

    // Add file with correct field name and MIME type
    final bytes = await imageFile.readAsBytes();
    final mimeType = _getMimeType(imageFile.name);
    request.files.add(http.MultipartFile.fromBytes(
      'foto_profile', 
      bytes,
      filename: imageFile.name,
      contentType: mimeType,
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Gagal mengupload foto. Status: ${response.statusCode}');
    }
  }

  @override
  Future<Map<String, dynamic>> deleteFoto() async {
    final response = await http.delete(
      Uri.parse(ApiConstants.profileFoto),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Gagal menghapus foto. Status: ${response.statusCode}');
    }
  }
}
