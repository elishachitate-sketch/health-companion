import 'package:flutter_test/flutter_test.dart';
import 'package:health_companion/services/health_data.dart';

void main() {
  final dataService = DataService.instance;

  test('local chat tone detection prioritizes tired and worried terms', () {
    expect(
      dataService
          .detectChatTone('I feel tired today but better than yesterday'),
      ChatTone.tired,
    );
    expect(dataService.detectChatTone('I am worried about this'),
        ChatTone.worried);
  });

  test('local chat tone detection recognizes hopeful and calm terms', () {
    expect(dataService.detectChatTone('I feel hopeful'), ChatTone.hopeful);
    expect(dataService.detectChatTone('I feel calm and okay'), ChatTone.calm);
  });

  test('local chat tone detection defaults to neutral', () {
    expect(dataService.detectChatTone('I went for a walk'), ChatTone.neutral);
  });
}
