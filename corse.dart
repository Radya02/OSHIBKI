import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../core/theme.dart';
import '../services/api_service.dart';

class CreatePostPage extends StatefulWidget {
  final int courseId;
  const CreatePostPage({super.key, required this.courseId});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _pointsCtrl = TextEditingController();

  String _postType = 'announcement';
  DateTime? _dueDate;
  List<File> _attachedFiles = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _pointsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'gif',
        'mp3',
        'wav',
        'aac',
        'm4a',
        'pdf',
        'doc',
        'docx',
      ],
    );

    if (result != null) {
      setState(() {
        _attachedFiles.addAll(
          result.paths.where((p) => p != null).map((p) => File(p!)),
        );
      });
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );

    if (result != null) {
      setState(() {
        _attachedFiles.addAll(
          result.paths.where((p) => p != null).map((p) => File(p!)),
        );
      });
    }
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.audio,
    );

    if (result != null) {
      setState(() {
        _attachedFiles.addAll(
          result.paths.where((p) => p != null).map((p) => File(p!)),
        );
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _attachedFiles.removeAt(index);
    });
  }

  String _getFileIcon(String path) {
    final ext = path.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif'].contains(ext)) return '🖼️';
    if (['mp3', 'wav', 'aac', 'm4a'].contains(ext)) return '🎵';
    if (['pdf'].contains(ext)) return '📄';
    if (['doc', 'docx'].contains(ext)) return '📝';
    return '📎';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      int? points;
      if (_postType == 'assignment' && _pointsCtrl.text.isNotEmpty) {
        points = int.tryParse(_pointsCtrl.text);
      }

      await ApiService.createPost(
        courseId: widget.courseId,
        type: _postType,
        title: _titleCtrl.text.trim(),
        content: _contentCtrl.text.trim(),
        dueDate: _postType == 'assignment' ? _dueDate : null,
        points: points,
        files: _attachedFiles.isNotEmpty ? _attachedFiles : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Пост создан успешно')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.bgSecondary,
      appBar: AppBar(
        title: const Text('Создать пост'),
        backgroundColor: c.bgPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Тип поста
                  DropdownButtonFormField<String>(
                    value: _postType,
                    decoration: const InputDecoration(labelText: 'Тип поста'),
                    items: const [
                      DropdownMenuItem(
                        value: 'announcement',
                        child: Text('Объявление'),
                      ),
                      DropdownMenuItem(
                        value: 'assignment',
                        child: Text('Задание'),
                      ),
                      DropdownMenuItem(
                        value: 'material',
                        child: Text('Материал'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _postType = v ?? 'announcement'),
                  ),
                  const SizedBox(height: 16),

                  // Заголовок
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(labelText: 'Заголовок'),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Введите заголовок' : null,
                  ),
                  const SizedBox(height: 16),

                  // Содержание
                  TextFormField(
                    controller: _contentCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Содержание',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 6,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Введите текст' : null,
                  ),
                  const SizedBox(height: 16),

                  // Поля для задания
                  if (_postType == 'assignment') ...[
                    TextFormField(
                      controller: _pointsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Баллы (опционально)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _dueDate == null
                            ? 'Срок сдачи не выбран'
                            : 'Срок: ${_dueDate!.day}.${_dueDate!.month}.${_dueDate!.year}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: _pickDueDate,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Кнопки прикрепления файлов
                  const Text(
                    'Прикрепить файлы:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.image),
                          label: const Text('Фото'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickAudio,
                          icon: const Icon(Icons.audiotrack),
                          label: const Text('Аудио'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickFiles,
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Файл'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Список прикрепленных файлов
                  if (_attachedFiles.isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Прикрепленные файлы:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    ..._attachedFiles.asMap().entries.map((entry) {
                      final index = entry.key;
                      final file = entry.value;
                      final fileName = file.path.split('/').last;
                      final isImage = [
                        'jpg',
                        'jpeg',
                        'png',
                        'gif',
                      ].contains(fileName.split('.').last.toLowerCase());

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: isImage
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.file(
                                    file,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Text(
                                  _getFileIcon(file.path),
                                  style: const TextStyle(fontSize: 24),
                                ),
                          title: Text(
                            fileName,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => _removeFile(index),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Опубликовать'),
                  ),
                ],
              ),
            ),
    );
  }
}
