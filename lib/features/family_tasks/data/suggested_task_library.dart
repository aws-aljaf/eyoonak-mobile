/// Static, client-only lookup tables for the family tasks feature — same
/// pattern as `permissionModuleLabels`
/// (mobile/lib/features/admin/data/admin_role_models.dart): plain `const`
/// maps duplicated here rather than fetched from the backend, because
/// these are UI-only groupings/labels the server never returns a
/// human-readable form of on its own.
///
/// `familyTaskCategoryLabels` mirrors `FamilyTask::CATEGORIES`
/// (backend/app/Models/FamilyTask.php) exactly, verified directly against
/// that constant — 7 entries, not 6: the plan's "6 categories" describes
/// `suggestedTaskLibrary` below (the picker a parent chooses a *suggestion*
/// from), while `custom` is an always-available 7th value for a task that
/// doesn't fit any of the six and has no suggestions of its own.
const Map<String, String> familyTaskCategoryLabels = {
  'study': 'دراسة',
  'worship': 'عبادة',
  'sports': 'رياضة',
  'home': 'منزل',
  'family_activities': 'أنشطة عائلية',
  'personal_growth': 'نمو شخصي',
  'custom': 'مخصصة',
};

/// Mirrors `FamilyTask::RECURRENCE_TYPES` exactly. See
/// `GenerateFamilyTaskOccurrences::isDueToday()` (backend) for what each
/// value actually means day-to-day: `once` fires a single time ever,
/// `daily` every day, `specific_days` only on the weekdays listed in
/// `recurrence_days`, `weekly` once a week on the same weekday as
/// `start_date`, `monthly` once a month on the same day-of-month as
/// `start_date` — the create/edit form only asks for `recurrence_days`
/// explicitly (when `specific_days` is picked); the other three derive
/// their due day from `start_date` alone, with no extra input needed.
const Map<String, String> familyTaskRecurrenceLabels = {
  'once': 'مرة واحدة',
  'daily': 'يومي',
  'specific_days': 'أيام محددة',
  'weekly': 'أسبوعي (نفس يوم البداية)',
  'monthly': 'شهري (نفس تاريخ البداية)',
};

/// Mirrors `FamilyTask::STATUSES` exactly.
const Map<String, String> familyTaskStatusLabels = {
  'active': 'نشطة',
  'archived': 'مؤرشفة',
};

/// Mirrors `FamilyTaskOccurrence::STATUSES` exactly.
const Map<String, String> familyTaskOccurrenceStatusLabels = {
  'pending_sync': 'محفوظ على الجهاز · بانتظار المزامنة',
  'pending': 'قيد الانتظار',
  'pending_approval': 'بانتظار موافقة الوالد',
  'approved': 'معتمدة',
  'rejected': 'مرفوضة',
  'missed': 'فائتة',
};

/// PR-67: mirrors `FamilyReward::STATUSES` exactly.
const Map<String, String> familyRewardStatusLabels = {
  'active': 'نشطة',
  'archived': 'مؤرشفة',
};

/// PR-67: mirrors `FamilyRewardRedemption::STATUSES` exactly.
const Map<String, String> familyRewardRedemptionStatusLabels = {
  'pending': 'بانتظار موافقة الوالد',
  'approved': 'مُعتمَد',
  'rejected': 'مرفوض',
};

/// PR-68: mirrors `FamilyChallenge::STATUSES` exactly.
const Map<String, String> familyChallengeStatusLabels = {
  'active': 'نشط',
  'completed': 'مكتمل',
  'archived': 'مؤرشف',
};

/// ISO-8601 weekday numbers (1=Monday..7=Sunday) — matches
/// `Carbon::dayOfWeekIso`, which is exactly what
/// `GenerateFamilyTaskOccurrences::isDueToday()` compares
/// `recurrence_days` against on the backend, and what
/// `StoreFamilyTaskRequest`'s `recurrence_days.*` rule (`between:1,7`)
/// validates. Used to build the "أيام محددة" weekday picker in the
/// create/edit form.
const Map<int, String> weekdayLabels = {
  1: 'الاثنين',
  2: 'الثلاثاء',
  3: 'الأربعاء',
  4: 'الخميس',
  5: 'الجمعة',
  6: 'السبت',
  7: 'الأحد',
};

/// One entry in `suggestedTaskLibrary` below — a starting point a parent
/// can pick, then freely edit (title/points included) before saving, never
/// something the app creates or activates on its own. See plan judgment
/// call #6: this is a purely static, client-side catalog with no
/// age-based logic — `family_members` has no `birth_date`/age column today.
class SuggestedTask {
  const SuggestedTask({required this.title, required this.defaultPoints});

  final String title;
  final int defaultPoints;
}

/// The suggestion library backing the create/edit form's "اقتراحات" picker
/// — one list per suggestable category (the 6 the plan names explicitly;
/// `custom` has none, since by definition it doesn't fit the other six).
/// Every title/points pair here is a plain suggestion: picking one only
/// prefills the title and points fields, both still fully editable before
/// saving, and a parent may equally ignore this section and type a task
/// from scratch.
const Map<String, List<SuggestedTask>> suggestedTaskLibrary = {
  'study': [
    SuggestedTask(title: 'قراءة كتاب', defaultPoints: 10),
    SuggestedTask(title: 'حل واجب مدرسي', defaultPoints: 10),
    SuggestedTask(title: 'مراجعة الدروس', defaultPoints: 10),
  ],
  'worship': [
    SuggestedTask(title: 'الصلاة في وقتها', defaultPoints: 5),
    SuggestedTask(title: 'حفظ سورة', defaultPoints: 15),
    SuggestedTask(title: 'الذكر اليومي', defaultPoints: 5),
  ],
  'sports': [
    SuggestedTask(title: 'تمرين رياضي', defaultPoints: 10),
    SuggestedTask(title: 'المشي 30 دقيقة', defaultPoints: 10),
    SuggestedTask(title: 'ممارسة رياضة مفضلة', defaultPoints: 10),
  ],
  'home': [
    SuggestedTask(title: 'ترتيب الغرفة', defaultPoints: 5),
    SuggestedTask(title: 'غسل الصحون', defaultPoints: 5),
    SuggestedTask(title: 'ترتيب السرير', defaultPoints: 5),
  ],
  'family_activities': [
    SuggestedTask(title: 'زيارة الجد والجدة', defaultPoints: 10),
    SuggestedTask(title: 'وجبة عائلية مشتركة', defaultPoints: 10),
    SuggestedTask(title: 'مساعدة أحد الوالدين', defaultPoints: 10),
  ],
  'personal_growth': [
    SuggestedTask(title: 'قراءة قبل النوم', defaultPoints: 5),
    SuggestedTask(title: 'كتابة يوميات', defaultPoints: 5),
    SuggestedTask(title: 'تعلم مهارة جديدة', defaultPoints: 15),
  ],
};
