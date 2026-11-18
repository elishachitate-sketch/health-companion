class ReviewSummary {
  const ReviewSummary({
    required this.name,
    required this.age,
    required this.language,
    required this.summaryDate,
    required this.sleepNote,
    required this.activityNote,
    required this.nutritionNote,
    required this.brainExerciseNote,
    required this.familyHistoryNote,
    required this.nextStepNote,
  });

  final String name;
  final String age;
  final String language;
  final String summaryDate;
  final String sleepNote;
  final String activityNote;
  final String nutritionNote;
  final String brainExerciseNote;
  final String familyHistoryNote;
  final String nextStepNote;
}

ReviewSummary getIllustrativeSummary() => const ReviewSummary(
      name: 'Amal',
      age: '58',
      language: 'English',
      summaryDate: '04 NOV 2026',
      sleepNote: 'Illustrative data: sleep routine varies from day to day.',
      activityNote:
          'Illustrative data: regular daily movement is a personal goal.',
      nutritionNote:
          'Illustrative data: balanced meals are part of the wellbeing plan.',
      brainExerciseNote:
          'Illustrative data: short brain exercise sessions are available.',
      familyHistoryNote:
          'Illustrative data: family history has not been provided.',
      nextStepNote:
          'No diagnosis or referral has been decided. A qualified professional should review abnormal or rapidly changing findings.',
    );
