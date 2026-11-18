import 'package:flutter_test/flutter_test.dart';
import 'package:health_companion/services/visit_routing_metadata.dart';

void main() {
  test('sudden confusion is routed urgently', () {
    final result = VisitRoutingMetadata.fromText(
      'My mother suddenly became confused today.',
      source: 'typed_text',
    );
    expect(result.urgentHandoff, isTrue);
    expect(result.route, 'urgent_handoff');
    expect(result.flags, contains('sudden_confusion'));
  });

  test('hearing and daily function concerns request clinician review', () {
    final hearing = VisitRoutingMetadata.fromText('I have trouble hearing.');
    final function = VisitRoutingMetadata.fromText(
      'I am struggling with everyday tasks and need more help.',
    );
    expect(hearing.route, 'clinician_review');
    expect(hearing.hearingConcern, isTrue);
    expect(function.route, 'clinician_review');
    expect(function.dailyFunctionDifficulty, isTrue);
    expect(function.urgentHandoff, isFalse);
  });

  test('unrelated messages have no routing flags', () {
    final result = VisitRoutingMetadata.fromText('I slept well last night.');
    expect(result.requiresRouting, isFalse);
    expect(result.route, 'none');
  });

  test('Arabic sudden confusion and daily function are routed', () {
    final urgent = VisitRoutingMetadata.fromText('حدث ارتباك مفاجئ اليوم');
    final daily =
        VisitRoutingMetadata.fromText('أحتاج مساعدة أكثر في الأعمال اليومية');
    expect(urgent.route, 'urgent_handoff');
    expect(daily.route, 'clinician_review');
  });
}
