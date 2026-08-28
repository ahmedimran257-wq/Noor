import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silarah/core/services/coach_mark_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('coach marks are shown once per member and can be disabled', () async {
    SharedPreferences.setMockInitialValues({});
    final memberA = CoachMarkService(userId: 'member-a');
    final memberB = CoachMarkService(userId: 'member-b');

    expect(await memberA.shouldShow('discover'), isTrue);
    await memberA.markSeen('discover');
    expect(await memberA.shouldShow('discover'), isFalse);
    expect(await memberA.shouldShow('chat'), isTrue);
    expect(await memberB.shouldShow('discover'), isTrue);

    await memberA.disableAll();
    expect(await memberA.shouldShow('chat'), isFalse);
    expect(await memberB.shouldShow('chat'), isTrue);
  });
}
