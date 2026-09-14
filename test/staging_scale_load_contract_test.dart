import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String scenario;
  late String runner;
  late String workflow;

  setUpAll(() {
    scenario = File('load-tests/staging_scale_paths.js').readAsStringSync();
    runner = File('tool/run_staging_load_test.mjs').readAsStringSync();
    workflow = File(
      '.github/workflows/staging-scale-load-test.yml',
    ).readAsStringSync();
  });

  test('capacity test ramps through 600 and permits only 600-1000 VUs', () {
    expect(scenario, contains('[600, 800, 1000].includes(peakVus)'));
    expect(scenario, contains('{ duration: "2m", target: 600 }'));
    expect(scenario, contains('{ duration: "3m", target: 600 }'));
    expect(scenario, contains('{ duration: "90s", target: 800 }'));
    expect(scenario, contains('{ duration: "90s", target: 1000 }'));
    expect(runner, contains('[600, 800, 1000].includes(maxVus)'));
  });

  test('production and accidental scale execution are blocked twice', () {
    for (final source in [scenario, runner]) {
      expect(source, contains('jukpscfxzwttgtxvrbmj'));
      expect(source, contains('I_UNDERSTAND_STAGING_SCALE_LOAD'));
      expect(source, contains('staging'));
    }
    expect(scenario, contains('Safety stop: production'));
    expect(runner, contains('Refusing to run load automation against'));
    expect(workflow, contains('confirm_staging_only'));
    expect(workflow, contains('environment: staging'));
  });

  test('workload is realistic, bounded and automatically aborts', () {
    expect(scenario, contains('abortOnFail: true'));
    expect(scenario, contains('discardResponseBodies: true'));
    expect(scenario, contains('p_page_size: 10'));
    expect(scenario, contains('sleep(8 +'));
    expect(scenario, contains('get_discovery_feed'));
    expect(scenario, contains('get_interest_quota'));
    expect(scenario, contains('get_profile_view_quota'));
    expect(scenario, contains('get_discovery_filter_access'));
    expect(scenario, isNot(contains('send_interest')));
    expect(scenario, isNot(contains('/storage/v1/object')));
  });

  test('fixtures are complete, bounded and cleaned even after failure', () {
    expect(runner, contains('? 40'));
    expect(runner, contains('Scale profile population is incomplete'));
    expect(runner, contains('/rest/v1/profile_preferences'));
    expect(runner, contains('finally'));
    expect(runner, contains('for (const fixture of fixtures)'));
    expect(runner, contains('cleanupAllLoadFixtures'));
    expect(runner, contains('LOAD_TEST_CLEANUP_ONLY'));
    expect(runner, contains('assertFixtureCleanup'));
    expect(runner, contains('TEST_USER_IDS'));
  });

  test('workflow is manual and exposes only the three reviewed peaks', () {
    expect(workflow, contains('workflow_dispatch'));
    expect(workflow, isNot(contains('schedule:')));
    for (final peak in ['"600"', '"800"', '"1000"']) {
      expect(workflow, contains(peak));
    }
    expect(workflow, contains('timeout-minutes: 30'));
    expect(
      RegExp(r'uses:\s+\S+@[0-9a-f]{40}').allMatches(workflow).length,
      4,
    );
  });
}
