import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:waterwali_app/main.dart';
import 'package:waterwali_app/services/auth_provider.dart';

void main() {
  testWidgets('App starts on splash/login without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (context) => AuthProvider(),
        child: const MyApp(),
      ),
    );

    // Just confirm it builds without throwing — this app has no counter,
    // so there's nothing meaningful to assert yet beyond "it launches."
    await tester.pump();
  });
}