/// A paginated list response, matching section 5 of the API spec
/// (`meta.current_page/per_page/total/last_page`).
class ApiEnvelope {
  const ApiEnvelope({required this.data, required this.meta});

  final List<dynamic> data;
  final Map<String, dynamic> meta;

  int get currentPage => (meta['current_page'] as num?)?.toInt() ?? 1;

  int get lastPage => (meta['last_page'] as num?)?.toInt() ?? 1;

  bool get hasMorePages => currentPage < lastPage;
}
