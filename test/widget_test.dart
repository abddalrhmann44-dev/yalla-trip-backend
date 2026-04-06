import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:talaa/firebase_options.dart';
import 'package:talaa/main.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  });

  testWidgets('App launches without crash', (WidgetTester tester) async {
    await tester.pumpWidget(const TalaaApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
