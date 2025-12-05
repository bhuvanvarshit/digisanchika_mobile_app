// lib/utils/connection_test.dart
import 'package:digi_sanchika/services/api_service.dart';

class ConnectionTest {
  // Test if backend is reachable
  static Future<void> testBackendConnection() async {
    print('🔄 Testing connection to backend...');

    final isConnected = await ApiService.checkConnection();

    if (isConnected) {
      print('✅ SUCCESS! Backend is reachable at: ${ApiService.currentBaseUrl}');
    } else {
      print(
        '❌ FAILED! Cannot connect to backend at: ${ApiService.currentBaseUrl}',
      );
      print('Please check:');
      print('1. Is the server running at ${ApiService.currentBaseUrl}?');
      print('2. Is your internet connection working?');
      print('3. Is the port 8000 open?');
    }
  }

  // Test login with test credentials
  static Future<void> testLogin() async {
    print('🔐 Testing login API...');

    // Replace with your actual test credentials
    const testEmail = 'test@example.com';
    const testPassword = 'password123';

    final result = await ApiService.login(testEmail, testPassword);

    if (result['success'] == true) {
      print('✅ LOGIN SUCCESSFUL!');
      print('Response data: ${result['data']}');
      print('Token received: ${result['token'] != null ? "YES" : "NO"}');
    } else {
      print('❌ LOGIN FAILED!');
      print('Error: ${result['message']}');

      // Check what type of error
      if (result['message'].toString().contains('Invalid email or password')) {
        print(
          '💡 Note: This might be expected if test credentials are incorrect',
        );
        print('But it confirms the API is working!');
      }
    }
  }

  // Run all tests
  static Future<void> runAllTests() async {
    print('🚀 Running backend connection tests...\n');

    await testBackendConnection();
    print('');

    await testLogin();
    print('');

    print('📋 Test Summary:');
    print(
      '1. Backend connection: ${await ApiService.checkConnection() ? "✅" : "❌"}',
    );
    print('2. API response: Tested via login endpoint');
    print('3. Token storage: ${await ApiService.isLoggedIn() ? "✅" : "❌"}');
  }
}
