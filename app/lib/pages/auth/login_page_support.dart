enum LoginPageMode { signIn, signUp }

enum LoginValidationCode {
  emailRequired,
  invalidEmail,
  passwordRequired,
  passwordTooShort,
  confirmPasswordRequired,
  passwordMismatch,
}

enum LoginFeedbackCode {
  actionCancelled,
  networkIssue,
  invalidCredentials,
  emailAlreadyInUse,
  accountExistsDifferentCredential,
  tooManyAttempts,
  googleConfiguration,
  generic,
}

const int minimumSignUpPasswordLength = 8;

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

LoginValidationCode? validateLoginEmail(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return LoginValidationCode.emailRequired;
  if (!_emailPattern.hasMatch(normalized)) {
    return LoginValidationCode.invalidEmail;
  }
  return null;
}

LoginValidationCode? validateLoginPassword(
  String value, {
  required bool requireMinimumLength,
}) {
  if (value.isEmpty) return LoginValidationCode.passwordRequired;
  if (requireMinimumLength && value.length < minimumSignUpPasswordLength) {
    return LoginValidationCode.passwordTooShort;
  }
  return null;
}

LoginValidationCode? validatePasswordConfirmation({
  required String password,
  required String confirmation,
}) {
  if (confirmation.isEmpty) {
    return LoginValidationCode.confirmPasswordRequired;
  }
  if (password != confirmation) {
    return LoginValidationCode.passwordMismatch;
  }
  return null;
}

LoginFeedbackCode classifyLoginFeedback(Object error) {
  final raw = error.toString().trim().toLowerCase();
  if (raw.isEmpty) return LoginFeedbackCode.generic;

  if (raw.contains('annul') || raw.contains('cancel')) {
    return LoginFeedbackCode.actionCancelled;
  }

  if (raw.contains('network') ||
      raw.contains('réseau') ||
      raw.contains('reseau')) {
    return LoginFeedbackCode.networkIssue;
  }

  if (raw.contains('email-already-in-use') ||
      raw.contains('already in use') ||
      raw.contains('déjà utilisé') ||
      raw.contains('deja utilise')) {
    return LoginFeedbackCode.emailAlreadyInUse;
  }

  if (raw.contains('account-exists-with-different-credential') ||
      raw.contains('autre méthode') ||
      raw.contains('autre methode') ||
      raw.contains('different sign-in method')) {
    return LoginFeedbackCode.accountExistsDifferentCredential;
  }

  if (raw.contains('too-many-requests') ||
      raw.contains('too many requests') ||
      raw.contains('trop de tentatives')) {
    return LoginFeedbackCode.tooManyAttempts;
  }

  if ((raw.contains('google') && raw.contains('jeton')) ||
      raw.contains('oauth google') ||
      raw.contains('configuration oauth') ||
      raw.contains('google token')) {
    return LoginFeedbackCode.googleConfiguration;
  }

  if (raw.contains('invalid-credential') ||
      raw.contains('invalid credential') ||
      raw.contains('identifiants invalides') ||
      raw.contains('wrong-password') ||
      raw.contains('user-not-found') ||
      raw.contains('aucun compte')) {
    return LoginFeedbackCode.invalidCredentials;
  }

  return LoginFeedbackCode.generic;
}
