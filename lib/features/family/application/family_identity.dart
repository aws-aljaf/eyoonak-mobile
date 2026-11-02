const familyKinships = <String, String>{
  'father': 'الأب',
  'mother': 'الأم',
  'son': 'الابن',
  'daughter': 'البنت',
  'grandfather': 'الجد',
  'grandmother': 'الجدة',
  'brother': 'الأخ',
  'sister': 'الأخت',
  'relative': 'قريب / ولي أمر',
};
const founderKinships = <String, String>{
  'father': 'الأب',
  'mother': 'الأم',
  'son': 'الابن',
  'daughter': 'البنت',
  'grandfather': 'الجد',
  'grandmother': 'الجدة',
  'relative': 'ولي أمر / قريب',
};
const deviceRelationships = <String, String>{
  'self': 'جهازي أنا',
  'son': 'ابني',
  'daughter': 'بنتي',
  'husband': 'زوجي',
  'wife': 'زوجتي',
  'father': 'أبي',
  'mother': 'أمي',
  'other': 'فرد آخر من العائلة',
};
bool readableFamilyName(String? value) =>
    value != null &&
    value.trim().isNotEmpty &&
    !value.contains('?') &&
    !value.contains('؟') &&
    !value.contains('\uFFFD');
