import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shadow_talk_flutter/screens/onboarding/otp_verify_screen.dart';
import 'package:shadow_talk_flutter/screens/onboarding/phone_entry_screen.dart';

void main() {
  testWidgets('Continue shows the SMS verify dialog with Edit/OK',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: PhoneEntryScreen()));

    // Enter a phone number.
    await tester.enterText(find.byType(TextField), '612345678');
    await tester.pump();

    // Tap Continue.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Dialog shows the full number and both actions.
    expect(find.textContaining('verify your number'), findsOneWidget);
    expect(find.textContaining('612345678'), findsAtLeastNWidgets(1));
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);

    // Edit dismisses the dialog (stays on the phone screen).
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('OK'), findsNothing);
    expect(find.text('Enter your phone number'), findsOneWidget);
  });

  testWidgets('Empty number is rejected (no dialog)', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: PhoneEntryScreen()));
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('OK'), findsNothing);
  });

  testWidgets('OTP shows the number, countdown, then Try Again; back confirms',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: OtpVerifyScreen(phoneNumber: '+31 612345678')),
    );

    // Number shown in subtitle + countdown visible.
    expect(find.textContaining('+31 612345678'), findsOneWidget);
    expect(find.textContaining('Resend code in'), findsOneWidget);

    // Back shows the cancel-confirmation dialog with Yes/No.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.textContaining('cancel the request to verify'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);
    // No keeps us on the screen.
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    expect(find.text('Verify your number'), findsOneWidget);

    // After the countdown elapses, the Try Again button appears.
    await tester.pump(const Duration(seconds: 121));
    await tester.pumpAndSettle();
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.textContaining('Resend code in'), findsNothing);
  });
}
