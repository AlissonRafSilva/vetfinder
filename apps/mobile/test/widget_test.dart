import 'package:flutter_test/flutter_test.dart';
import 'package:vetfinder_mobile/app/vetfinder_app.dart';

void main() {
  testWidgets('renderiza o shell inicial do VetFinder', (WidgetTester tester) async {
    await tester.pumpWidget(const VetFinderApp());

    expect(find.text('VetFinder'), findsOneWidget);
    expect(find.text('Entrada'), findsOneWidget);
  });
}
