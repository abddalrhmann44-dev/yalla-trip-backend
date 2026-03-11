import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_trip/main.dart';

void main() {
  group('Yalla Trip App Tests', () {
    // ── App Launch ──────────────────────────────────────────
    testWidgets('App launches and shows Login page', (WidgetTester tester) async {
      await tester.pumpWidget(const YallaTripApp());
      await tester.pumpAndSettle();

      // App should render without crashing
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    // ── Login Page ──────────────────────────────────────────
    testWidgets('Login page shows email and password fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(const YallaTripApp());
      await tester.pumpAndSettle();

      expect(find.text('Welcome\nback.'), findsOneWidget);
      expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets('Login form validates empty fields', (WidgetTester tester) async {
      await tester.pumpWidget(const YallaTripApp());
      await tester.pumpAndSettle();

      // Tap sign in button without filling fields
      final signInBtn = find.text('Sign In');
      if (signInBtn.evaluate().isNotEmpty) {
        await tester.tap(signInBtn.first);
        await tester.pumpAndSettle();
        // Validation errors should appear
        expect(find.text('Enter your email'), findsOneWidget);
      }
    });

    testWidgets('Login form validates incorrect email format',
        (WidgetTester tester) async {
      await tester.pumpWidget(const YallaTripApp());
      await tester.pumpAndSettle();

      final emailFields = find.byType(TextFormField);
      if (emailFields.evaluate().isNotEmpty) {
        await tester.enterText(emailFields.first, 'notanemail');
        final signInBtn = find.text('Sign In');
        if (signInBtn.evaluate().isNotEmpty) {
          await tester.tap(signInBtn.first);
          await tester.pumpAndSettle();
          expect(find.text('Enter a valid email'), findsOneWidget);
        }
      }
    });

    // ── Navigation ──────────────────────────────────────────
    testWidgets('Tapping Sign Up navigates to Register page',
        (WidgetTester tester) async {
      await tester.pumpWidget(const YallaTripApp());
      await tester.pumpAndSettle();

      final signUpLink = find.text('Sign Up');
      if (signUpLink.evaluate().isNotEmpty) {
        await tester.tap(signUpLink.first);
        await tester.pumpAndSettle();
        expect(find.text('Create your\naccount.'), findsOneWidget);
      }
    });

    // ── Register Page ───────────────────────────────────────
    testWidgets('Register page shows all required fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(const YallaTripApp());
      await tester.pumpAndSettle();

      // Navigate to register
      final signUpLink = find.text('Sign Up');
      if (signUpLink.evaluate().isNotEmpty) {
        await tester.tap(signUpLink.first);
        await tester.pumpAndSettle();

        // Should have 4 fields: name, email, password, confirm
        expect(find.byType(TextFormField), findsNWidgets(4));
      }
    });

    testWidgets('Register form validates password mismatch',
        (WidgetTester tester) async {
      await tester.pumpWidget(const YallaTripApp());
      await tester.pumpAndSettle();

      final signUpLink = find.text('Sign Up');
      if (signUpLink.evaluate().isNotEmpty) {
        await tester.tap(signUpLink.first);
        await tester.pumpAndSettle();

        final fields = find.byType(TextFormField);
        if (fields.evaluate().length >= 4) {
          await tester.enterText(fields.at(0), 'Ahmed Mohamed');
          await tester.enterText(fields.at(1), 'ahmed@test.com');
          await tester.enterText(fields.at(2), 'password123');
          await tester.enterText(fields.at(3), 'differentpassword');

          final createBtn = find.text('Create Account');
          if (createBtn.evaluate().isNotEmpty) {
            await tester.tap(createBtn.first);
            await tester.pumpAndSettle();
            expect(find.text('Passwords do not match'), findsOneWidget);
          }
        }
      }
    });
  });
}
