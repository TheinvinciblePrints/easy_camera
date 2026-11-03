import 'package:flutter_easy_camera_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home page shows both demos', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Snap a meal (AI demo)'), findsOneWidget);
    expect(find.text('Basic capture'), findsOneWidget);
  });
}
