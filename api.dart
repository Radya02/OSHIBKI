// services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/course.dart';
import '../models/post.dart';
import '../models/submission.dart';
import '../models/user.dart';
import 'package:file_picker/file_picker.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  static Future<void> createPost({
  required int courseId,
  required String type,
  required String title,
  required String content,
  DateTime? dueDate,
  int? points,
  List<PlatformFile>? files, // ИЗМЕНИ ТИП ТУТ с List<File> на List<PlatformFile>
}) async {
  final formDataMap = {
    'course': courseId,
    'type': type,
    'title': title,
    'content': content,
  };

  if (dueDate != null) formDataMap['due_date'] = dueDate.toIso8601String();
  if (points != null) formDataMap['points'] = points;

  final formData = FormData.fromMap(formDataMap);

  // Обработка файлов
  if (files != null && files.isNotEmpty) {
    for (var file in files) {
      if (kIsWeb) {
        // Для Веба используем байты
        if (file.bytes != null) {
          formData.files.add(MapEntry(
            'attachments',
            MultipartFile.fromBytes(file.bytes!, filename: file.name),
          ));
        }
      } else {
        // Для Эмулятора (Android) используем путь
        if (file.path != null) {
          formData.files.add(MapEntry(
            'attachments',
            await MultipartFile.fromFile(file.path!, filename: file.name),
          ));
        }
      }
    }
  }

  // Твой код отправки через dio.post(...)
  // await _dio.post('/posts/', data: formData);
}

  static Future<Submission> submitAssignment({
    required int postId,
    String? comment,
    List<File>? files,
  }) async {
    final req =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/submissions/'))
          ..headers.addAll(_multipartHeaders())
          ..fields['post'] = postId.toString();

    if (comment != null && comment.isNotEmpty) {
      req.fields['text'] = comment;
    }

    if (files != null && files.isNotEmpty) {
      for (final f in files) {
        req.files.add(await http.MultipartFile.fromPath('files', f.path));
      }
    }

    final streamedResponse = await req.send();
    final response = await http.Response.fromStream(streamedResponse);

    return Submission.fromJson(_handle(response));
  }

  static final _storage = FlutterSecureStorage();
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  static User? _currentUser;
  static String? _accessToken;

  static User? get currentUser => _currentUser;
  static bool get isLoggedIn => _accessToken != null;
  static bool get isTeacher => _currentUser?.role == 'teacher';

  // ─── Заголовки ────────────────────────────────────────────────────────────
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  static Map<String, String> _multipartHeaders() => {
    'Accept': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  // ─── Инициализация ────────────────────────────────────────────────────────
  static Future<void> init() async {
    _accessToken = await _storage.read(key: _accessKey);
    if (_accessToken != null) {
      try {
        await fetchProfile();
      } catch (_) {
        await _tryRefresh();
      }
    }
  }

  // ─── Обработка ответа ─────────────────────────────────────────────────────
  static dynamic _handle(http.Response res) {
    if (res.statusCode == 204) return {};
    if (res.body.isEmpty) return {};

    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) return body;

    String msg = 'Ошибка запроса (${res.statusCode})';
    if (body is Map) msg = body['detail']?.toString() ?? body.toString();
    throw Exception(msg);
  }

  static List<dynamic> _parseList(dynamic data) {
    if (data is Map && data.containsKey('results'))
      return data['results'] as List;
    if (data is List) return data;
    return [];
  }

  // ─── AUTH ──────────────────────────────────────────────────────────────────
  static Future<User?> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/register/'),
      headers: _headers,
      body: jsonEncode({
        'username': email,
        'email': email,
        'name': name,
        'password': password,
        'password2': password,
        'role': role,
      }),
    );
    final data = _handle(res);
    await _saveTokens(data['access'] ?? '', data['refresh'] ?? '');
    return _currentUser;
  }

  static Future<User?> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login/'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = _handle(res);
    await _saveTokens(data['access'] ?? '', data['refresh'] ?? '');
    return _currentUser;
  }

  static Future<User?> fetchProfile() async {
    final res = await http.get(
      Uri.parse('$baseUrl/auth/profile/'),
      headers: _headers,
    );
    _currentUser = User.fromJson(_handle(res));
    return _currentUser;
  }

  // ─── COURSES ───────────────────────────────────────────────────────────────
  static Future<List<Course>> getCourses() async {
    final res = await http.get(
      Uri.parse('$baseUrl/courses/'),
      headers: _headers,
    );
    return _parseList(_handle(res)).map((e) => Course.fromJson(e)).toList();
  }

  static Future<Course> getCourse(int id) async {
    final res = await http.get(
      Uri.parse('$baseUrl/courses/$id/'),
      headers: _headers,
    );
    return Course.fromJson(_handle(res));
  }

  static Future<Course> createCourse({
    required String title,
    required String description,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/courses/'),
      headers: _headers,
      body: jsonEncode({'title': title, 'description': description}),
    );
    return Course.fromJson(_handle(res));
  }

  static Future<Course?> findCourseByCode(String code) async {
    final res = await http.get(
      Uri.parse('$baseUrl/courses/find/$code/'),
      headers: _headers,
    );
    if (res.statusCode == 404) return null;
    return Course.fromJson(_handle(res));
  }

  static Future<void> joinCourse(int courseId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/courses/$courseId/enroll/'),
      headers: _headers,
    );
    _handle(res);
  }

  static Future<Map<String, dynamic>> getCourseMembers(int courseId) async {
    final studentsRes = await http.get(
      Uri.parse('$baseUrl/courses/$courseId/students/'),
      headers: _headers,
    );
    final students = _parseList(
      _handle(studentsRes),
    ).map((e) => User.fromJson(e)).toList();
    final course = await getCourse(courseId);
    return {'teacher': course.teacher, 'students': students};
  }

  // ─── POSTS ─────────────────────────────────────────────────────────────────
  static Future<List<Post>> getCourseFeed(int courseId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/posts/?course=$courseId'),
      headers: _headers,
    );
    return _parseList(_handle(res)).map((e) => Post.fromJson(e)).toList();
  }

  static Future<List<Post>> getCourseAssignments(int courseId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/posts/?course=$courseId&type=assignment'),
      headers: _headers,
    );
    return _parseList(_handle(res)).map((e) => Post.fromJson(e)).toList();
  }

  static Future<List<Post>> getDeadlines() async {
    final res = await http.get(
      Uri.parse('$baseUrl/posts/?deadlines=true'),
      headers: _headers,
    );
    return _parseList(_handle(res)).map((e) => Post.fromJson(e)).toList();
  }

  static Future<Post> getPost(int postId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/posts/$postId/'),
      headers: _headers,
    );
    return Post.fromJson(_handle(res));
  }

  static Future<Post> createPost({
    required int courseId,
    required String type,
    required String title,
    required String content,
    DateTime? dueDate,
    int? points,
    List<PlatformFile>? files
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/posts/'))
      ..headers.addAll(_multipartHeaders())
      ..fields['course'] = courseId.toString()
      ..fields['type'] = type
      ..fields['title'] = title
      ..fields['content'] = content;

    if (dueDate != null) req.fields['due_date'] = dueDate.toIso8601String();
    if (points != null) req.fields['points'] = points.toString();

    if (files != null) {
      for (final file in files) {
        req.files.add(await http.MultipartFile.fromPath('files', file.path));
      }
    }

    final res = await http.Response.fromStream(await req.send());
    return Post.fromJson(_handle(res));
  }

  static Future<void> deletePost(int postId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/posts/$postId/'),
      headers: _headers,
    );
    _handle(res);
  }

  // ─── SUBMISSIONS ───────────────────────────────────────────────────────────
  static Future<List<Submission>> getSubmissions(int postId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/submissions/?post=$postId'),
      headers: _headers,
    );
    return _parseList(_handle(res)).map((e) => Submission.fromJson(e)).toList();
  }

  // Новое: метод для получения последних отправлений
  // Новое: метод для получения последних отправлений
  static Future<List<Submission>> getRecentSubmissions({int limit = 5}) async {
    // Используем getMySubmissions(), так как он не требует ID конкретного поста
    final allSubmissions = await ApiService.getMySubmissions();

    // Сортируем по дате (от новых к старым)
    allSubmissions.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    // Берем первые несколько элементов
    return allSubmissions.take(limit).toList();
  }

  static Future<List<Submission>> getMySubmissions() async {
    final res = await http.get(
      Uri.parse('$baseUrl/submissions/'),
      headers: _headers,
    );
    return _parseList(_handle(res)).map((e) => Submission.fromJson(e)).toList();
  }

  static Future<void> gradeSubmission(
    int submissionId,
    int grade,
    String feedback,
  ) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/submissions/$submissionId/grade/'),
      headers: _headers,
      body: jsonEncode({
        'grade': grade,
        'feedback': feedback,
        'status': 'graded',
      }),
    );
    _handle(res);
  }

  // ─── COMMENTS ──────────────────────────────────────────────────────────────
  static Future<List<Comment>> getComments(int postId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/comments/?post=$postId'),
      headers: _headers,
    );
    return _parseList(_handle(res)).map((e) => Comment.fromJson(e)).toList();
  }

  static Future<Comment> addComment(int postId, String text) async {
    final res = await http.post(
      Uri.parse('$baseUrl/comments/'),
      headers: _headers,
      body: jsonEncode({'post': postId, 'text': text}),
    );
    return Comment.fromJson(_handle(res));
  }

  static Future<void> deleteComment(int commentId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/comments/$commentId/'),
      headers: _headers,
    );
    _handle(res);
  }

  // ─── ТОКЕНЫ ────────────────────────────────────────────────────────────────
  static Future<void> _saveTokens(String access, String refresh) async {
    _accessToken = access;
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
    if (access.isNotEmpty) await fetchProfile();
  }

  static Future<void> logout() async {
    _accessToken = null;
    _currentUser = null;
    await _storage.deleteAll();
  }

  static Future<void> _tryRefresh() async {
    final refresh = await _storage.read(key: _refreshKey);
    if (refresh == null) {
      await logout();
      return;
    }

    final res = await http.post(
      Uri.parse('$baseUrl/token/refresh/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': refresh}),
    );
    if (res.statusCode == 200) {
      _accessToken = jsonDecode(res.body)['access'];
      await _storage.write(key: _accessKey, value: _accessToken!);
      await fetchProfile();
    } else {
      await logout();
    }
  }
}
