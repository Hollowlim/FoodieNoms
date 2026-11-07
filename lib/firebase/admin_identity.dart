const adminBootstrapEmail = String.fromEnvironment('ADMIN_LOGIN_EMAIL');

/// The username is the Gmail handle; the owner alias is supplied at build time.
/// This avoids a publicly readable username-to-email directory.
String adminEmailForLogin(String input,
    {String bootstrapEmail = adminBootstrapEmail}) {
  final value = input.trim().toLowerCase();
  if (value.contains('@')) return value;
  if (value == 'admin123') {
    if (bootstrapEmail.trim().isEmpty) {
      throw StateError(
          'The owner username is not configured on this build. Use your administrator email.');
    }
    return bootstrapEmail.trim().toLowerCase();
  }
  if (!RegExp(r'^[a-z0-9][a-z0-9._+\-]{0,100}$').hasMatch(value)) {
    throw StateError('Enter your admin username or email address.');
  }
  return '$value@gmail.com';
}

String adminUsernameForEmail(String email) {
  final value = email.trim().toLowerCase();
  return value.endsWith('@gmail.com')
      ? value.substring(0, value.length - 10)
      : value;
}
