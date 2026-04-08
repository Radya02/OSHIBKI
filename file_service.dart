import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

class FileService {
  static Future<({String name, String path})?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result == null || result.files.single.path == null) return null;

    return (name: result.files.single.name, path: result.files.single.path!);
  }

  static Future<String> uploadFile(String localPath, String fileName) async {
    // 10.0.2.2 — это стандартный IP для доступа к localhost из эмулятора Android
    final uri = Uri.parse('http://10.0.2.2:8000/api/upload/');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', localPath));

    // Добавьте заголовки, если нужна авторизация
    // request.headers['Authorization'] = 'Bearer $yourToken';

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['url']
          as String; // Убедитесь, что Django возвращает ключ 'url'
    } else {
      throw Exception('Ошибка загрузки: ${response.statusCode}');
    }
  }

  // Остальные методы (formatSize, extensionLabel) остаются без изменений
}
