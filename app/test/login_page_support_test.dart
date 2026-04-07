import 'package:flutter_test/flutter_test.dart';
import 'package:masslive/pages/auth/login_page_support.dart';

void main() {
  group('login page validation', () {
    test('validate email detects missing and invalid values', () {
      expect(validateLoginEmail(''), LoginValidationCode.emailRequired);
      expect(
        validateLoginEmail('invalid-email'),
        LoginValidationCode.invalidEmail,
      );
      expect(validateLoginEmail('user@example.com'), isNull);
    });

    test('validate password only enforces minimum length for sign up', () {
      expect(
        validateLoginPassword('', requireMinimumLength: false),
        LoginValidationCode.passwordRequired,
      );
      expect(
        validateLoginPassword('123456', requireMinimumLength: false),
        isNull,
      );
      expect(
        validateLoginPassword('1234567', requireMinimumLength: true),
        LoginValidationCode.passwordTooShort,
      );
      expect(
        validateLoginPassword('12345678', requireMinimumLength: true),
        isNull,
      );
    });

    test('validate password confirmation detects empty and mismatch', () {
      expect(
        validatePasswordConfirmation(password: 'secret123', confirmation: ''),
        LoginValidationCode.confirmPasswordRequired,
      );
      expect(
        validatePasswordConfirmation(
          password: 'secret123',
          confirmation: 'secret124',
        ),
        LoginValidationCode.passwordMismatch,
      );
      expect(
        validatePasswordConfirmation(
          password: 'secret123',
          confirmation: 'secret123',
        ),
        isNull,
      );
    });
  });

  group('login page feedback classification', () {
    test('classifies common auth failures', () {
      expect(
        classifyLoginFeedback('FirebaseAuthException: wrong-password'),
        LoginFeedbackCode.invalidCredentials,
      );
      expect(
        classifyLoginFeedback('network-request-failed'),
        LoginFeedbackCode.networkIssue,
      );
      expect(
        classifyLoginFeedback('Connexion Google annulée'),
        LoginFeedbackCode.actionCancelled,
      );
      expect(
        classifyLoginFeedback('email-already-in-use'),
        LoginFeedbackCode.emailAlreadyInUse,
      );
      expect(
        classifyLoginFeedback('account-exists-with-different-credential'),
        LoginFeedbackCode.accountExistsDifferentCredential,
      );
      expect(
        classifyLoginFeedback('too-many-requests'),
        LoginFeedbackCode.tooManyAttempts,
      );
      expect(
        classifyLoginFeedback(
          'Google n\'a pas renvoyé de jeton valide. Vérifiez la configuration OAuth Google.',
        ),
        LoginFeedbackCode.googleConfiguration,
      );
    });
  });
}
