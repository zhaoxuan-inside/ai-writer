import 'package:ai_writer/app/ai_writer_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows library empty prompt without login', (tester) async {
    await tester.pumpWidget(const AiWriterApp());
    expect(find.text('Choose a folder to start writing.'), findsOneWidget);
    expect(find.textContaining('No account required'), findsOneWidget);
  });
}
