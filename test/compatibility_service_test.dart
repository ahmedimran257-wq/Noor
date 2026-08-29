import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/services/compatibility_service.dart';

void main() {
  test('parses an explainable mutual compatibility response', () {
    final insight = CompatibilityInsight.fromJson({
      'matched_count': 3,
      'total_count': 4,
      'criteria': [
        {
          'key': 'age',
          'matched_count': 2,
          'total_count': 2,
          'status': 'aligned',
        },
        {
          'key': 'sect',
          'matched_count': 1,
          'total_count': 2,
          'status': 'partial',
        },
      ],
      'disclaimer': 'Stated preferences only.',
    });

    expect(insight.matchedCount, 3);
    expect(insight.totalCount, 4);
    expect(insight.fraction, .75);
    expect(insight.criteria, hasLength(2));
    expect(insight.criteria.first.status, 'aligned');
  });

  test('handles a profile pair with no stated preferences', () {
    final insight = CompatibilityInsight.fromJson({
      'matched_count': 0,
      'total_count': 0,
      'criteria': <Map<String, dynamic>>[],
      'disclaimer': 'Stated preferences only.',
    });

    expect(insight.fraction, 0);
    expect(insight.criteria, isEmpty);
  });
}
