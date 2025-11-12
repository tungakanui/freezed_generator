// Simple standalone test for the generator
// Run with: dart tool/test_generator.dart

import '../lib/generator.dart';

void main() {
  print('🚀 Testing Freezed Generator with Advanced Algorithm...\n');

  final generator = FreezedGenerator(
    config: const GeneratorConfig(
      makeFieldsNullable: true,
      detectDateTime: true,
      detectEnums: true,
    ),
  );

  // Test 1: Pattern Recognition
  print('=' * 70);
  print('Test 1: Pattern Recognition');
  print('=' * 70);
  final json1 = '''{
    "user_id": "123",
    "is_active": true,
    "follower_count": 1250,
    "rating_score": 4.8,
    "created_at": "2024-01-15T10:30:00Z",
    "profile_url": "https://example.com/profile"
  }''';

  final result1 = generator.generate('User', json1);
  print(result1);
  print('');

  // Test 2: Nested Objects
  print('=' * 70);
  print('Test 2: Nested Objects');
  print('=' * 70);
  final json2 = '''{
    "user": {
      "profile": {
        "name": "John",
        "email_address": "john@example.com"
      }
    }
  }''';

  final result2 = generator.generate('Root', json2);
  print(result2);
  print('');

  // Test 3: Lists
  print('=' * 70);
  print('Test 3: Lists');
  print('=' * 70);
  final json3 = '''{
    "numbers": [1, 2, 3],
    "names": ["Alice", "Bob"],
    "users": [
      {"id": 1, "name": "Alice"},
      {"id": 2, "name": "Bob"}
    ]
  }''';

  final result3 = generator.generate('Data', json3);
  print(result3);
  print('');

  // Test 4: Multi-sample Analysis
  print('=' * 70);
  print('Test 4: Multi-sample Analysis');
  print('=' * 70);
  final json4 = '''[
    {"value": 10, "name": "Alice"},
    {"value": 20.5, "name": "Bob"},
    {"value": 30, "name": "Charlie"}
  ]''';

  final result4 = generator.generate('Sample', json4);
  print(result4);
  print('');

  // Test 5: Complex Real-World Example
  print('=' * 70);
  print('Test 5: Complex Real-World Example');
  print('=' * 70);
  final json5 = '''{
    "user_id": "usr_123",
    "username": "johndoe",
    "email_address": "john@example.com",
    "is_active": true,
    "created_at": "2024-01-15T10:30:00Z",
    "last_login_date": "2024-01-20",
    "follower_count": 1250,
    "rating_score": 4.8,
    "profile": {
      "avatar_url": "https://example.com/avatar.jpg",
      "bio": "Software Developer"
    },
    "posts": [
      {
        "post_id": 1,
        "title": "My First Post",
        "published_date": "2024-01-16T08:00:00Z",
        "likes_count": 42,
        "is_pinned": false
      }
    ],
    "tags": ["tech", "coding", "flutter"]
  }''';

  final result5 = generator.generate('User', json5);
  print(result5);
  print('');

  print('=' * 70);
  print('✅ All tests completed successfully!');
  print('=' * 70);
}
