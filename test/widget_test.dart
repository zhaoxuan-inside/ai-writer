import 'package:ai_writer/app/ai_writer_app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows library empty prompt without login', (tester) async {
    await tester.pumpWidget(const AiWriterApp());
    await tester.pumpAndSettle();
    expect(find.text('Choose a folder to start writing.'), findsOneWidget);
    expect(find.textContaining('No account required'), findsOneWidget);
    expect(find.text('Choose folder'), findsOneWidget);
  });
}
