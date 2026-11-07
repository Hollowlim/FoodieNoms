import 'package:flutter_test/flutter_test.dart';
import 'package:foodienoms/firebase/admin_identity.dart';

void main() {
  test('owner username resolves only from the configured login email', () {
    expect(
        adminEmailForLogin(' ADMIN123 ',
            bootstrapEmail: 'owner+admin@gmail.com'),
        'owner+admin@gmail.com');
    expect(() => adminEmailForLogin('Admin123', bootstrapEmail: ''),
        throwsStateError);
  });
  test(
      'Gmail usernames and full email addresses resolve without a public directory',
      () {
    expect(adminEmailForLogin(' Staff.Admin '), 'staff.admin@gmail.com');
    expect(
        adminEmailForLogin('staff+foodienoms'), 'staff+foodienoms@gmail.com');
    expect(adminEmailForLogin('Staff@Example.org'), 'staff@example.org');
    expect(adminUsernameForEmail('staff+admin@gmail.com'), 'staff+admin');
    expect(adminUsernameForEmail('staff@example.org'), 'staff@example.org');
    expect(() => adminEmailForLogin('name with spaces'), throwsStateError);
    expect(() => adminEmailForLogin('https://bad'), throwsStateError);
  });
}
