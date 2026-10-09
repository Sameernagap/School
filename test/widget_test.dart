import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/api/api_client.dart';
import 'package:school_app/utils/format.dart';

void main() {
  test('server address is normalised', () {
    expect(ApiClient.normalizeServer('192.168.1.5:8069/'), 'http://192.168.1.5:8069');
    expect(ApiClient.normalizeServer('https://school.example.com/api/v1'), 'https://school.example.com');
  });

  test('api urls', () {
    final api = ApiClient(serverUrl: 'http://10.0.2.2:8069');
    expect(api.url('/me'), 'http://10.0.2.2:8069/api/v1/me');
    expect(api.url('/api/v1/students/1/photo'), 'http://10.0.2.2:8069/api/v1/students/1/photo');
  });

  test('formatting', () {
    expect(fmtMoney({'amount': 1234567.5, 'symbol': '₹'}), '₹1,234,567.50');
    expect(fmtDate('2026-10-09'), '9 Oct 2026');
    expect(initials('Aarav Patil'), 'AP');
    expect(fmtNum(45.0), '45');
  });
}
