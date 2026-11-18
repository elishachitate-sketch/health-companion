/// Privacy-minimized routing hints derived from user-entered or transcribed text.
///
/// This is a conservative navigation signal, not clinical interpretation. The
/// server must re-evaluate the original text and must not trust these hints as
/// authorization or a diagnosis.
class VisitRoutingMetadata {
  const VisitRoutingMetadata({
    required this.suddenConfusion,
    required this.hearingConcern,
    required this.dailyFunctionDifficulty,
    required this.source,
  });

  final bool suddenConfusion;
  final bool hearingConcern;
  final bool dailyFunctionDifficulty;
  final String source;

  bool get requiresRouting =>
      suddenConfusion || hearingConcern || dailyFunctionDifficulty;
  bool get urgentHandoff => suddenConfusion;

  List<String> get flags => [
        if (suddenConfusion) 'sudden_confusion',
        if (hearingConcern) 'hearing_concern',
        if (dailyFunctionDifficulty) 'daily_function_difficulty',
      ];

  String get route => urgentHandoff
      ? 'urgent_handoff'
      : requiresRouting
          ? 'clinician_review'
          : 'none';

  Map<String, Object> toJson() => {
        'schemaVersion': 'visit-routing-v1',
        'source': source,
        'flags': flags,
        'route': route,
        'urgentHandoff': urgentHandoff,
      };

  factory VisitRoutingMetadata.fromText(
    String text, {
    String source = 'user_report',
  }) {
    final normalized = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final suddenConfusion = _matchesAny(normalized, [
      RegExp(
          r'\b(sudden(?:ly)?|all of a sudden|new onset|acute)\b.{0,60}\b(confus\w*|disorient\w*|not know where|not know who)\b'),
      RegExp(
          r'\b(confus\w*|disorient\w*)\b.{0,60}\b(sudden(?:ly)?|all of a sudden|started today|new onset)\b'),
      RegExp(r'(ارتباك|تشوش|حيرة).{0,24}(مفاجئ|فجأة|حديث)'),
      RegExp(r'(مفاجئ|فجأة|حديث).{0,24}(ارتباك|تشوش|حيرة)'),
    ]);
    final hearingConcern = _matchesAny(normalized, [
      RegExp(
          r'\b(hearing concern|hearing loss|harder to hear|difficulty hearing|trouble hearing|cannot hear|can\x27t hear)\b'),
      RegExp(
          r'\b(hearing)\b.{0,30}\b(problem|difficulty|concern|worse|decline)\b'),
      RegExp(r'(ضعف السمع|صعوبة في السمع|مشكلة في السمع|لا أسمع جيداً)'),
    ]);
    final dailyFunctionDifficulty = _matchesAny(normalized, [
      RegExp(
          r'\b(difficulty|difficult|struggle|struggling|need more help|harder)\b.{0,60}\b(daily|everyday|usual)\b.{0,30}\b(task|activit|routine|chores|function)\w*'),
      RegExp(
          r'\b(daily|everyday|usual)\b.{0,30}\b(task|activit|routine|chores)\w*.{0,40}\b(difficulty|difficult|struggle|harder|help)\b'),
      RegExp(
          r'\b(help|manage|managing)\b.{0,40}\b(medicines|medication|shopping|cooking|appointments|bathing|dressing)\b.{0,30}\b(harder|difficult|struggle|more)\b'),
      RegExp(
          r'(صعوبة في المهام اليومية|صعوبة في الأعمال اليومية|أحتاج مساعدة أكثر|أحتاج إلى مساعدة أكثر)'),
    ]);
    return VisitRoutingMetadata(
      suddenConfusion: suddenConfusion,
      hearingConcern: hearingConcern,
      dailyFunctionDifficulty: dailyFunctionDifficulty,
      source: source,
    );
  }

  static bool _matchesAny(String text, List<RegExp> patterns) =>
      patterns.any((pattern) => pattern.hasMatch(text));
}
