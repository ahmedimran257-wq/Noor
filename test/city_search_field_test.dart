import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mithaq/core/services/country_context_service.dart';
import 'package:mithaq/core/widgets/inputs/city_search_field.dart';

void main() {
  testWidgets('clears the selected city when the country changes',
      (tester) async {
    final country = ValueNotifier('IN');
    var clearedCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<String>(
            valueListenable: country,
            builder: (_, value, __) => CitySearchField(
              countryCode: value,
              initialValue: 'Delhi, Delhi',
              onCleared: () => clearedCount++,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Delhi, Delhi');

    country.value = 'US';
    await tester.pump();
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    expect(clearedCount, 1);
  });

  testWidgets('does not enable city search without a selected country',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CitySearchField(
            countryCode: null,
            enabled: false,
            onSelected: (CityResult _) {},
          ),
        ),
      ),
    );

    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  });
}
