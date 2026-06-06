import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ImageKitService {
  static final ImageKitService _instance = ImageKitService._internal();
  factory ImageKitService() => _instance;
  ImageKitService._internal();

  Future<String?> uploadImage(File imageFile, String fileName) async {
    try {
      final urlEndpoint = dotenv.env['IMAGEKIT_URL_ENDPOINT'];
      final publicKey = dotenv.env['IMAGEKIT_PUBLIC_KEY'];
      final privateKey = dotenv.env['IMAGEKIT_PRIVATE_KEY'];

      if (urlEndpoint == null || publicKey == null || privateKey == null) {
        print('ImageKit credentials missing in .env');
        return null;
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://upload.imagekit.io/api/v1/files/upload'),
      );

      // Add basic auth using private key
      String basicAuth = 'Basic ' + base64Encode(utf8.encode('$privateKey:'));
      request.headers['Authorization'] = basicAuth;

      request.fields['fileName'] = fileName;
      request.fields['useUniqueFileName'] = 'true';
      request.fields['folder'] = '/couple_profiles';

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
        ),
      );

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(responseData);
        return jsonResponse['url'];
      } else {
        print('Failed to upload image: ${response.statusCode}');
        print('Response: $responseData');
        return null;
      }
    } catch (e) {
      print('Error uploading to ImageKit: $e');
      return null;
    }
  }
}
