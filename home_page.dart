import 'package:flutter/material.dart';
import '../app.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../models/course.dart';
import '../models/post.dart';
import '../models/submission.dart';
import '../services/api_service.dart';
import '../widgets/bottom_navbar.dart';
import '../widgets/course_card.dart';
import 'course_page.dart';
import 'create_course_page.dart';
import 'join_course_page.dart';
import 'settings_page.dart';
import 'create_post.dart';
import 'select_course_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentTab = 0;

  final GlobalKey<_TeacherDashboardTabState> _teacherHomeKey = GlobalKey();
  final GlobalKey<_StudentDashboardTabState> _studentHomeKey = GlobalKey();
  final GlobalKey<_CoursesTabState> _coursesTabKey = GlobalKey();

  // ✅ Метод для обновления вкладок после вступления в курс
  void refreshAfterJoin() {
    _coursesTabKey.currentState?._refresh();
    _studentHomeKey.currentState?._refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isTeacher = ApiService.isTeacher;
    return Scaffold(
      backgroundColor: context.colors.bgSecondary,
      body: IndexedStack(
        index: _currentTab,
        children: [
          isTeacher
              ? _TeacherDashboardTab(key: _teacherHomeKey)
              : _StudentDashboardTab(key: _studentHomeKey),
          _CoursesTab(key: _coursesTabKey),
          const _ProfileTab(),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentTab,
        onTap: (i) => setState(() => _currentTab = i),
      ),
    );
  }
}

// ─── STUDENT DASHBOARD ────────────────────────────────────────────────────────

class _StudentDashboardTab extends StatefulWidget {
  const _StudentDashboardTab({super.key});
  @override
  State<_StudentDashboardTab> createState() => _StudentDashboardTabState();
}

class _StudentDashboardTabState extends State<_StudentDashboardTab> {
  late Future<_StudentDashData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _dataFuture = _loadData();
    });
  }

  Future<_StudentDashData> _loadData() async {
    final courses = await ApiService.getCourses();
    final allPosts = <Post>[];
    for (final course in courses) {
      final posts = await ApiService.getCourseFeed(course.id);
      allPosts.addAll(posts);
    }
    final deadlines =
        allPosts.where((p) => p.isAssignment && p.dueDate != null).toList()
          ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    return _StudentDashData(courses: courses, deadlines: deadlines);
  }

  @override
  Widget build(BuildContext context) {
    final user = ApiService.currentUser;
    return ListenableBuilder(
      listenable: languageNotifier,
      builder: (context, _) {
        final c = context.colors;
        return SafeArea(
          child: FutureBuilder<_StudentDashData>(
            future: _dataFuture,
            builder: (context, snapshot) {
              final data = snapshot.data;
              final loading =
                  snapshot.connectionState == ConnectionState.waiting;
              return CustomScrollView(
                slivers: [
                  _AppBar(title: 'LearnHub', showNotification: true),
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Text(
                          '${context.s.greeting}, ${user?.name.split(' ').first ?? ''}! 👋',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.s.todaySummary,
                          style: TextStyle(
                            fontSize: 15,
                            color: c.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        loading
                            ? _StatsShimmer()
                            : _StatsRow(
                                cards: [
                                  _StatData(
                                    Icons.menu_book_rounded,
                                    '${data?.courses.length ?? 0}',
                                    context.s.coursesCount,
                                    AppTheme.primary,
                                  ),
                                  _StatData(
                                    Icons.assignment_outlined,
                                    '${data?.deadlines.length ?? 0}',
                                    context.s.assignmentsCount,
                                    AppTheme.warning,
                                  ),
                                  _StatData(
                                    Icons.warning_amber_rounded,
                                    '${data?.deadlines.where((p) => p.dueDate!.isBefore(DateTime.now())).length ?? 0}',
                                    context.s.overdueCount,
                                    AppTheme.danger,
                                  ),
                                ],
                              ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Text(
                              context.s.upcomingDead,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            if (!loading &&
                                (data?.deadlines.isNotEmpty ?? false))
                              Text(
                                '${data!.deadlines.length} ${context.s.total}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: c.textTertiary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (loading) ...[
                          _DeadlineShimmer(),
                          const SizedBox(height: 10),
                          _DeadlineShimmer(),
                        ] else if (data == null || data.deadlines.isEmpty)
                          _EmptyDeadlines()
                        else
                          ...data.deadlines
                              .take(5)
                              .map((post) => _DeadlineCard(post: post)),
                      ]),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _StudentDashData {
  final List<Course> courses;
  final List<Post> deadlines;
  const _StudentDashData({required this.courses, required this.deadlines});
}

// ─── TEACHER DASHBOARD ────────────────────────────────────────────────────────

class _TeacherDashboardTab extends StatefulWidget {
  const _TeacherDashboardTab({super.key});
  @override
  State<_TeacherDashboardTab> createState() => _TeacherDashboardTabState();
}

class _TeacherDashboardTabState extends State<_TeacherDashboardTab> {
  late Future<_TeacherDashData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _dataFuture = _loadData();
    });
  }

  Future<_TeacherDashData> _loadData() async {
    final courses = await ApiService.getCourses();
    final submissions = await ApiService.getRecentSubmissions();
    int totalStudents = 0;
    int totalAssignments = 0;
    for (final course in courses) {
      totalStudents += course.memberCount;
      final posts = await ApiService.getCourseFeed(course.id);
      totalAssignments += posts.where((p) => p.isAssignment).length;
    }
    return _TeacherDashData(
      courses: courses,
      recentSubmissions: submissions.take(5).toList(),
      totalStudents: totalStudents,
      totalAssignments: totalAssignments,
      pendingCount: submissions.where((s) => !s.isGraded).length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ApiService.currentUser;
    return ListenableBuilder(
      listenable: languageNotifier,
      builder: (context, _) {
        final c = context.colors;
        final s = context.s;
        return SafeArea(
          child: FutureBuilder<_TeacherDashData>(
            future: _dataFuture,
            builder: (context, snapshot) {
              final data = snapshot.data;
              final loading =
                  snapshot.connectionState == ConnectionState.waiting;
              return CustomScrollView(
                slivers: [
                  _AppBar(
                    title: 'LearnHub',
                    showNotification: true,
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: TextButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CreateCoursePage(),
                              ),
                            );
                            _refresh();
                          },
                          icon: const Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: AppTheme.primary,
                          ),
                          label: Text(
                            s.createCourse,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Text(
                          '${s.greeting}, ${user?.name.split(' ').first ?? ''}! 👋',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.todaySummary,
                          style: TextStyle(
                            fontSize: 15,
                            color: c.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        loading
                            ? _StatsShimmer()
                            : _StatsRow(
                                cards: [
                                  _StatData(
                                    Icons.menu_book_rounded,
                                    '${data?.courses.length ?? 0}',
                                    s.coursesCount,
                                    AppTheme.primary,
                                  ),
                                  _StatData(
                                    Icons.group_outlined,
                                    '${data?.totalStudents ?? 0}',
                                    s.totalStudents,
                                    AppTheme.success,
                                  ),
                                  _StatData(
                                    Icons.assignment_outlined,
                                    '${data?.pendingCount ?? 0}',
                                    s.pendingLabel,
                                    AppTheme.warning,
                                  ),
                                ],
                              ),
                        const SizedBox(height: 24),
                        Text(
                          s.recentSubmissions,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (loading) ...[
                          _DeadlineShimmer(),
                          const SizedBox(height: 10),
                          _DeadlineShimmer(),
                        ] else if (data == null ||
                            data.recentSubmissions.isEmpty)
                          _EmptySubmissions()
                        else
                          ...data.recentSubmissions.map(
                            (s) => _SubmissionCard(submission: s),
                          ),
                      ]),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _TeacherDashData {
  final List<Course> courses;
  final List<Submission> recentSubmissions;
  final int totalStudents, totalAssignments, pendingCount;
  const _TeacherDashData({
    required this.courses,
    required this.recentSubmissions,
    required this.totalStudents,
    required this.totalAssignments,
    required this.pendingCount,
  });
}

class _SubmissionCard extends StatelessWidget {
  final Submission submission;
  const _SubmissionCard({required this.submission});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isGraded = submission.isGraded;
    final color = isGraded ? AppTheme.success : AppTheme.warning;
    final label = isGraded ? context.s.gradedLabel : context.s.pendingLabel;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bgPrimary,
        borderRadius: BorderRadius.circular(14),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySubmissions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.bgPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 40, color: c.textTertiary),
          const SizedBox(height: 10),
          Text(
            context.s.noSubmissions,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SHARED APPBAR ────────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  final String title;
  final bool showNotification;
  final List<Widget> actions;
  const _AppBar({
    required this.title,
    this.showNotification = false,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SliverAppBar(
      floating: true,
      backgroundColor: c.bgPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: c.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        ...actions,
        if (showNotification)
          IconButton(
            icon: Icon(
              Icons.notifications_none_rounded,
              color: c.textSecondary,
            ),
            onPressed: () {},
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: c.border),
      ),
    );
  }
}

class _StatData {
  final IconData icon;
  final String value, label;
  final Color color;
  const _StatData(this.icon, this.value, this.label, this.color);
}

class _StatsRow extends StatelessWidget {
  final List<_StatData> cards;
  const _StatsRow({required this.cards});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: cards
          .asMap()
          .entries
          .map(
            (e) => Expanded(
              child: Container(
                margin: EdgeInsets.only(left: e.key == 0 ? 0 : 12),
                child: _StatCard(data: e.value),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final _StatData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: c.bgPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: data.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, color: data.color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            data.value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 11,
              color: c.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── DEADLINE WIDGETS ─────────────────────────────────────────────────────────

class _DeadlineCard extends StatelessWidget {
  final Post post;
  const _DeadlineCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = DateTime.now();
    final due = post.dueDate!;
    final isOverdue = due.isBefore(now);
    final daysLeft = due.difference(now).inDays;
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

    Color statusColor;
    String statusLabel;
    if (isOverdue) {
      statusColor = AppTheme.danger;
      statusLabel = context.s.overdue;
    } else if (daysLeft == 0) {
      statusColor = AppTheme.danger;
      statusLabel = context.s.today;
    } else if (daysLeft <= 2) {
      statusColor = AppTheme.warning;
      statusLabel = '${context.s.inPrefix} $daysLeft ${context.s.inDays}';
    } else {
      statusColor = AppTheme.success;
      statusLabel = '${context.s.inPrefix} $daysLeft ${context.s.inDays}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bgPrimary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.assignment_outlined,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${months[due.month]} ${due.day}',
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDeadlines extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.bgPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 40,
            color: AppTheme.success,
          ),
          const SizedBox(height: 10),
          Text(
            context.s.noDeadlines,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.s.allDone,
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StatsShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: List.generate(
        3,
        (i) => Expanded(
          child: Container(
            margin: EdgeInsets.only(left: i == 0 ? 0 : 12),
            height: 96,
            decoration: BoxDecoration(
              color: c.bgTertiary,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeadlineShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: c.bgTertiary,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}

// ─── COURSES TAB ──────────────────────────────────────────────────────────────

class _CoursesTab extends StatefulWidget {
  const _CoursesTab({super.key});
  @override
  State<_CoursesTab> createState() => _CoursesTabState();
}

class _CoursesTabState extends State<_CoursesTab> {
  late Future<List<Course>> _coursesFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _coursesFuture = ApiService.getCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTeacher = ApiService.isTeacher;
    return ListenableBuilder(
      listenable: languageNotifier,
      builder: (context, _) {
        final c = context.colors;
        final s = context.s;
        return SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                floating: true,
                backgroundColor: c.bgPrimary,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  s.myCourses,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                actions: [
                  if (isTeacher)
                    IconButton(
                      icon: const Icon(
                        Icons.add_rounded,
                        color: AppTheme.primary,
                      ),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateCoursePage(),
                          ),
                        );
                        _refresh();
                      },
                    )
                  else
                    // ✅ Кнопка вступить в курс для студента прямо на вкладке Courses
                    IconButton(
                      icon: const Icon(
                        Icons.add_rounded,
                        color: AppTheme.primary,
                      ),
                      onPressed: () async {
                        final joined = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const JoinCoursePage(),
                          ),
                        );
                        if (joined == true && context.mounted) {
                          _refresh();
                          // ✅ Также обновляем dashboard
                          context
                              .findAncestorStateOfType<_HomePageState>()
                              ?.refreshAfterJoin();
                        }
                      },
                    ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(height: 1, color: c.border),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                sliver: FutureBuilder<List<Course>>(
                  future: _coursesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.only(top: 60),
                            child: CircularProgressIndicator(
                              color: AppTheme.primary,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      );
                    }
                    final courses = snapshot.data ?? [];
                    if (courses.isEmpty) {
                      return SliverToBoxAdapter(
                        child: _EmptyCourses(isTeacher: isTeacher),
                      );
                    }
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => CourseCard(
                          course: courses[index],
                          colorIndex: index,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CoursePage(course: courses[index]),
                              ),
                            );
                            _refresh();
                          },
                        ),
                        childCount: courses.length,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyCourses extends StatelessWidget {
  final bool isTeacher;
  const _EmptyCourses({required this.isTeacher});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.s;
    return Container(
      margin: const EdgeInsets.only(top: 60),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.menu_book_outlined, size: 56, color: c.textTertiary),
          const SizedBox(height: 16),
          Text(
            isTeacher ? s.createCourse : s.joinTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isTeacher ? s.courseDesc : s.joinSub,
            style: TextStyle(fontSize: 14, color: c.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── PROFILE TAB ──────────────────────────────────────────────────────────────

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final user = ApiService.currentUser;
    final isTeacher = ApiService.isTeacher;

    return ListenableBuilder(
      listenable: Listenable.merge([themeNotifier, languageNotifier]),
      builder: (context, _) {
        final c = context.colors;
        final s = context.s;
        return SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: c.bgPrimary,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  s.profileTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(height: 1, color: c.border),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: c.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          size: 40,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        user?.name ?? '',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
                        style: TextStyle(fontSize: 14, color: c.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: c.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isTeacher ? s.teacher : s.student,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Действия учителя/студента
                      if (isTeacher) ...[
                        _ProfileAction(
                          icon: Icons.add_circle_outline_rounded,
                          label: s.createCourse,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CreateCoursePage(),
                              ),
                            );
                            context
                                .findAncestorStateOfType<_HomePageState>()
                                ?._teacherHomeKey
                                .currentState
                                ?._refresh();
                          },
                        ),
                        _ProfileAction(
                          icon: Icons.post_add_rounded,
                          label: "Создать пост",
                          onTap: () async {
                            final int? selectedCourseId =
                                await Navigator.push<int>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SelectCoursePage(),
                                  ),
                                );

                            if (selectedCourseId != null && context.mounted) {
                              final bool? created = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CreatePostPage(
                                    courseId: selectedCourseId,
                                  ),
                                ),
                              );

                              if (created == true && context.mounted) {
                                context
                                    .findAncestorStateOfType<_HomePageState>()
                                    ?._teacherHomeKey
                                    .currentState
                                    ?._refresh();
                              }
                            }
                          },
                        ),
                      ] else ...[
                        _ProfileAction(
                          icon: Icons.add_circle_outline_rounded,
                          label: s.joinTitle,
                          onTap: () async {
                            final joined = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const JoinCoursePage(),
                              ),
                            );
                            if (joined == true && context.mounted) {
                              context
                                  .findAncestorStateOfType<_HomePageState>()
                                  ?.refreshAfterJoin();
                            }
                          },
                        ),
                      ],
                      
                      _ProfileAction(
                        icon: Icons.settings_outlined,
                        label: s.settings,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsPage(),
                          ),
                        ),
                      ),

                      _ProfileAction(
                        icon: Icons.logout_rounded,
                        label: s.logout,
                        color: AppTheme.danger,
                        onTap: () async {
                          await ApiService.logout();
                          if (context.mounted) {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/',
                              (r) => false,
                            );
                          }
                        },
                      ),
                    ],
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

class _ProfileAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppTheme.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textColor = color == AppTheme.textPrimary ? c.textPrimary : color;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: c.bgPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: ListTile(
        leading: Icon(icon, color: textColor, size: 20),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: c.textTertiary,
          size: 20,
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
