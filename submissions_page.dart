import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/post.dart';
import '../models/submission.dart';
import '../services/api_service.dart';
import '../services/file_service.dart';

class SubmissionPage extends StatefulWidget {
  final Post post;
  const SubmissionPage({super.key, required this.post});

  @override
  State<SubmissionPage> createState() => _SubmissionPageState();
}

class _SubmissionPageState extends State<SubmissionPage> {
  final _commentCtrl = TextEditingController();
  final _submitCommentCtrl = TextEditingController();
  late List<Comment> _comments;
  bool _sending = false;
  bool _submitting = false;
  String? _pickedFileName;
  Submission? _mySubmission;

  @override
  void initState() {
    super.initState();
    _comments = List.from(widget.post.comments);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _submitCommentCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final comment = await ApiService.addComment(widget.post.id, text);
      setState(() {
        _comments.add(comment);
        _commentCtrl.clear();
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickFile() async {
    final file = await FileService.pickFile();
    if (file != null) setState(() => _pickedFileName = file.name);
  }

  Future<void> _submitAssignment() async {
    final comment = _submitCommentCtrl.text.trim();
    final fileName = _pickedFileName;

    setState(() => _submitting = true);

    try {
      String? fileUrl;
      if (fileName != null) {
        fileUrl = await FileService.uploadFile(
          '/mock/path/$fileName',
          fileName,
        );
      }

      final submission = await ApiService.submitAssignment(
        postId: widget.post.id,
        comment: comment.isEmpty ? null : comment,
        fileUrl: fileUrl,
        fileName: fileName,
      );

      if (!mounted) return;

      setState(() => _mySubmission = submission);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assignment submitted successfully!'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submission failed: $e'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final post = widget.post;
    final months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final isTeacher = ApiService.isTeacher;

    return Scaffold(
      backgroundColor: c.bgSecondary,
      appBar: AppBar(title: const Text('Assignment Details')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Assignment card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: c.bgPrimary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        post.content,
                        style: TextStyle(
                          fontSize: 15,
                          color: c.textSecondary,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (post.dueDate != null)
                            _InfoChip(
                              icon: Icons.schedule_rounded,
                              label:
                                  'Due ${months[post.dueDate!.month]} ${post.dueDate!.day}',
                              color: AppTheme.warning,
                              bgColor: c.warningLight,
                            ),
                          if (post.points != null)
                            _InfoChip(
                              icon: Icons.star_outline_rounded,
                              label: '${post.points} points',
                              color: AppTheme.primary,
                              bgColor: c.primaryLight,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (isTeacher)
                  _TeacherSubmissionsSection(postId: post.id)
                else
                  _mySubmission != null
                      ? _SubmittedBanner(submission: _mySubmission!)
                      : _SubmitSection(
                          pickedFileName: _pickedFileName,
                          commentCtrl: _submitCommentCtrl,
                          onPickFile: _pickFile,
                          onSubmit: _submitting ? null : _submitAssignment,
                          submitting: _submitting,
                        ),

                const SizedBox(height: 16),
                // Comments
                Container(
                  decoration: BoxDecoration(
                    color: c.bgPrimary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Text(
                          'Class comments',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                      if (_comments.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No comments yet.',
                            style: TextStyle(
                              color: c.textTertiary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ..._comments.map(
                        (comment) => _CommentTile(comment: comment),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
          // Comment input bar
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: c.bgPrimary,
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    style: TextStyle(fontSize: 15, color: c.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Add a class comment...',
                      hintStyle: TextStyle(color: c.textTertiary),
                      fillColor: c.bgTertiary,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: c.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                          color: AppTheme.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending ? null : _sendComment,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: _sending
                        ? const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _pickFile,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: c.bgTertiary,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.border),
                    ),
                    child: Icon(
                      Icons.attach_file_rounded,
                      color: c.textSecondary,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, bgColor;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Comment comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: comment.isTeacher ? c.primaryLight : c.bgTertiary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_rounded,
              size: 16,
              color: comment.isTeacher ? AppTheme.primary : c.textTertiary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      comment.timeAgo,
                      style: TextStyle(fontSize: 12, color: c.textTertiary),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  comment.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: c.textPrimary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: c.border),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitSection extends StatelessWidget {
  final String? pickedFileName;
  final TextEditingController commentCtrl;
  final VoidCallback onPickFile;
  final VoidCallback? onSubmit;
  final bool submitting;

  const _SubmitSection({
    required this.pickedFileName,
    required this.commentCtrl,
    required this.onPickFile,
    required this.onSubmit,
    required this.submitting,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.bgPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your submission',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onPickFile,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.bgTertiary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.attach_file_rounded,
                    size: 18,
                    color: c.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pickedFileName ?? 'Attach a file...',
                      style: TextStyle(
                        fontSize: 14,
                        color: pickedFileName != null
                            ? c.textPrimary
                            : c.textTertiary,
                      ),
                    ),
                  ),
                  if (pickedFileName != null)
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: AppTheme.success,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: commentCtrl,
            minLines: 2,
            maxLines: 4,
            style: TextStyle(fontSize: 14, color: c.textPrimary),
            decoration: InputDecoration(
              hintText: 'Add a private comment (optional)...',
              hintStyle: TextStyle(color: c.textTertiary),
              fillColor: c.bgTertiary,
              filled: true,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppTheme.primary,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: onSubmit,
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit Assignment'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmittedBanner extends StatelessWidget {
  final Submission submission;
  const _SubmittedBanner({required this.submission});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.successLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.success.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppTheme.success,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Assignment submitted!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.success,
                  ),
                ),
                if (submission.isGraded)
                  Text(
                    'Grade: ${submission.grade}/100  •  ${submission.feedback}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.success,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StudentsPage extends StatelessWidget {
  final int postId;
  const StudentsPage({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bgSecondary,
      appBar: AppBar(title: const Text('Submissions')),
      body: FutureBuilder<List<Submission>>(
        future: ApiService.getSubmissions(postId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primary,
                strokeWidth: 2,
              ),
            );
          }
          final submissions = snapshot.data ?? [];
          if (submissions.isEmpty) {
            return Center(
              child: Text(
                'No submissions yet.',
                style: TextStyle(color: c.textSecondary),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: submissions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _SubmissionTile(submission: submissions[i]),
          );
        },
      ),
    );
  }
}

class _TeacherSubmissionsSection extends StatefulWidget {
  final int postId;
  const _TeacherSubmissionsSection({required this.postId});

  @override
  State<_TeacherSubmissionsSection> createState() =>
      _TeacherSubmissionsSectionState();
}

class _TeacherSubmissionsSectionState
    extends State<_TeacherSubmissionsSection> {
  late Future<List<Submission>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getSubmissions(widget.postId);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FutureBuilder<List<Submission>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppTheme.primary,
              strokeWidth: 2,
            ),
          );
        }
        final submissions = snapshot.data ?? [];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.bgPrimary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Student Submissions',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${submissions.length} submitted',
                    style: TextStyle(fontSize: 13, color: c.textTertiary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (submissions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'No submissions yet.',
                      style: TextStyle(color: c.textTertiary),
                    ),
                  ),
                )
              else
                ...submissions.map(
                  (s) => _GradingTile(
                    submission: s,
                    onGraded: () => setState(
                      () => _future = ApiService.getSubmissions(widget.postId),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _GradingTile extends StatefulWidget {
  final Submission submission;
  final VoidCallback onGraded;
  const _GradingTile({required this.submission, required this.onGraded});

  @override
  State<_GradingTile> createState() => _GradingTileState();
}

class _GradingTileState extends State<_GradingTile> {
  bool _expanded = false;
  final _gradeCtrl = TextEditingController();
  final _feedbackCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _gradeCtrl.dispose();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveGrade() async {
    final grade = int.tryParse(_gradeCtrl.text.trim());
    if (grade == null || grade < 0 || grade > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid grade (0–100)'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService.gradeSubmission(
        widget.submission.id,
        grade,
        _feedbackCtrl.text.trim(),
      );
      if (mounted) {
        setState(() => _expanded = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Grade saved!'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onGraded();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = widget.submission;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: c.bgTertiary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: c.bgPrimary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_rounded,
                size: 18,
                color: c.textTertiary,
              ),
            ),
            title: Text(
              s.studentName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            subtitle: s.fileName != null
                ? Text(
                    s.fileName!,
                    style: TextStyle(fontSize: 12, color: c.textTertiary),
                  )
                : null,
            trailing: s.isGraded
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: c.successLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${s.grade}/100',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.success,
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      _expanded ? 'Cancel' : 'Grade',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
          if (_expanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  TextField(
                    controller: _gradeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Grade (0–100)',
                      fillColor: c.bgPrimary,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _feedbackCtrl,
                    minLines: 2,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Feedback (optional)',
                      fillColor: c.bgPrimary,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveGrade,
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Grade'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubmissionTile extends StatelessWidget {
  final Submission submission;
  const _SubmissionTile({required this.submission});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bgPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.bgTertiary,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_rounded, size: 20, color: c.textTertiary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  submission.studentName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                if (submission.fileName != null)
                  Text(
                    submission.fileName!,
                    style: TextStyle(fontSize: 12, color: c.textTertiary),
                  ),
              ],
            ),
          ),
          if (submission.isGraded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: c.successLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${submission.grade}/100',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.success,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: c.warningLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Pending',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.warning,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
