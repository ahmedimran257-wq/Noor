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

  test('replay is account isolated even when account names share a prefix',
      () async {
    SharedPreferences.setMockInitialValues({'unrelated': true});
    final member = CoachMarkService(userId: 'member-a');
    final cousin = CoachMarkService(userId: 'member-ab');
    await member.markSeen('discover');
    await member.disableAll();
    await cousin.markSeen('discover');
    await cousin.disableAll();
    final revision = CoachMarkService.replayRevision.value;
    await member.resetAll();
    expect(CoachMarkService.replayRevision.value, revision + 1);
    expect(await member.shouldShow('discover', alreadyUsed: true), isTrue);
    expect(await cousin.shouldShow('discover'), isFalse);
    expect(await cousin.shouldShow('chat'), isFalse);
    expect(
        (await SharedPreferences.getInstance()).getBool('unrelated'), isTrue);
    await member.markSeen('discover');
    expect(await member.shouldShow('discover', alreadyUsed: true), isFalse);
  });

  test('experienced members are not taught features they already use',
      () async {
    SharedPreferences.setMockInitialValues({});
    final member = CoachMarkService(userId: 'member-a');
    expect(await member.shouldShow('chat', alreadyUsed: true), isFalse);
    expect(await member.shouldShow('chat'), isTrue);
  });
}
