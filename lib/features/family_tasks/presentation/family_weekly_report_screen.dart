import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/family_tasks_providers.dart';
import '../data/family_task_models.dart';

/// "📊 التقرير الأسبوعي" (PR-70) — renders `GET /family-tasks/weekly-report`
/// (PR-64 backend) exactly as the backend structures it. This screen exists
/// specifically to honour plan judgment call #7 on the client side too:
/// `members` is rendered in whatever order the API returns it — NEVER
/// sorted by `tasksCompleted`/`pointsEarned`/anything else — mirroring the
/// backend's own deliberate "ordered by family_member_id, never by score"
/// choice (see `FamilyWeeklyReportController`'s own extensive docblock).
/// There is no "least accomplished" view, no negative comparison, and no
/// way to request one — the backend never sends that data in the first
/// place, and this screen adds nothing on top of what it receives. An
/// empty `highlights` entry renders as a neutral, non-judgmental empty
/// state ("لم يُحقق أحد رقمًا قياسيًا بعد") rather than anything implying
/// someone did poorly — mirrors the backend's own "zero never wins" rule.
class FamilyWeeklyReportScreen extends ConsumerWidget {
  const FamilyWeeklyReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(familyWeeklyReportProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('التقرير الأسبوعي')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(familyWeeklyReportProvider),
        child: reportAsync.when(
          data: (report) => _ReportBody(report: report),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _ErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(familyWeeklyReportProvider),
          ),
        ),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});

  final FamilyWeeklyReportModel report;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الأسبوع', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${report.weekStart} — ${report.weekEnd}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('🌟 تألق هذا الأسبوع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        _HighlightCard(
          icon: '🏆',
          title: 'الأكثر إنجازًا',
          entries: report.mostTasksCompleted,
          valueLabel: (value) => '$value مهمة',
          emptyText: 'لم يُحقق أحد رقمًا قياسيًا في عدد المهام هذا الأسبوع بعد.',
        ),
        const SizedBox(height: 8),
        _HighlightCard(
          icon: '📈',
          title: 'الأكثر تحسّنًا',
          entries: report.mostImproved,
          valueLabel: (value) => '+$value مهمة عن الأسبوع الماضي',
          emptyText: 'لا يوجد تحسّن ملحوظ لعرضه بعد هذا الأسبوع.',
        ),
        const SizedBox(height: 24),
        const Text('تفصيل كل فرد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        // Deliberately rendered in API order (== family_member_id order,
        // never by score) — see this screen's own docblock.
        if (report.members.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('لا يوجد أفراد نشطون لعرض تفصيلهم بعد.'),
          )
        else
          for (final member in report.members) _MemberRow(member: member),
      ],
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.icon,
    required this.title,
    required this.entries,
    required this.valueLabel,
    required this.emptyText,
  });

  final String icon;
  final String title;
  final List<FamilyWeeklyReportHighlightEntryModel> entries;
  final String Function(int value) valueLabel;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: entries.isEmpty ? null : Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$icon $title', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              Text(emptyText, style: TextStyle(color: Colors.grey.shade700))
            else
              // Every member tied for the max is listed together — never
              // an arbitrary single "winner" (see the backend's own
              // `topBy()` docblock: a tie is a reason to celebrate two
              // people, not to rank them).
              for (final entry in entries)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${entry.fullName} — ${valueLabel(entry.value)}'),
                ),
          ],
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member});

  final FamilyWeeklyReportMemberModel member;

  @override
  Widget build(BuildContext context) {
    final approvalText = member.approvalRate == null ? '—' : '${(member.approvalRate! * 100).round()}%';

    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text('${member.pointsEarned}')),
        title: Text(member.fullName),
        subtitle: Text('${member.tasksCompleted} مهمة مكتملة هذا الأسبوع • نسبة الاعتماد: $approvalText'),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('تعذر تحميل التقرير الأسبوعي: $message', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
