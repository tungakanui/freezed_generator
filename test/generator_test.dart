import 'package:flutter_test/flutter_test.dart';

// Import the generator from the project (relative import to main.dart).
import 'package:gen_model/main.dart';

void main() {
  group('FreezedGenerator - list handling', () {
    final gen = FreezedGenerator();

    test('homogeneous primitive list -> List<int>', () {
      const json = '{"values": [1, 2, 3]}';
      final out = gen.generate('Numbers', json);
      expect(out, contains('List<int>? values'));
    });

    test('mixed int and double -> List<double>', () {
      const json = '{"values": [1, 2.5, 3]}';
      final out = gen.generate('Numbers', json);
      expect(out, contains('List<double>? values'));
    });

    test('mixed primitives -> dynamic list', () {
      const json = '{"values": [1, "two", true]}';
      final out = gen.generate('Mixed', json);
      expect(out, contains('List<dynamic>? values'));
    });

    test('nested list -> List<List<int>>', () {
      const json = '{"matrix": [[1,2],[3,4]]}';
      final out = gen.generate('Matrix', json);
      // Should produce List<List<int>> or similar
      expect(out, contains('List<List<int>>? matrix'));
    });

    test('list of objects -> generates nested class and uses it', () {
      const json = '{"items": [{"id": 1, "name": "a"}, {"id": 2, "name": "b"}]}';
      final out = gen.generate('Container', json);
      // Should generate a nested class name (Items or Items2 etc.) and reference it
      expect(out, contains('List<'));
      expect(out, contains('items')); // field present
      // the generated class should contain the fields id and name
      expect(out, contains('int? id'));
      expect(out, contains('String? name'));
    });

    test('complex company model -> generates expected classes and fields', () {
      const json = r'{ "company": { "name": "Tech Solutions Inc.", "location": { "address": "123 Innovation Drive", "city": "Metropolis", "state": "CA", "zipCode": "90210" }, "departments": [ { "name": "Engineering", "head": "Dr. Sarah Chen", "employees": [ { "id": "EMP001", "firstName": "John", "position": "Software Engineer", "skills": ["Python", "Java", "Cloud Computing"] }, { "id": "EMP002", "firstName": "Jane", "lastName": "Smith", "position": "DevOps Engineer", "skills": ["Docker", "Kubernetes", "AWS"] } ], "projects": [ { "projectId": "PROJ001", "status": "In Progress" }, { "projectId": "PROJ002", "projectName": "Project Beta", "status": "Completed" } ] }, { "name": "Marketing", "employees": [ { "id": "EMP003", "firstName": "Emily", "lastName": "White", "position": "Marketing Specialist", "skills": ["SEO", "Content Creation", "Social Media"] } ], "campaigns": [ { "campaignId": "CAMP001", "campaignName": "Product Launch Q4", "budget": 50000 } ] } ] }, "financials": { "revenueLastQuarter": 1500000, "fiscalYearEnd": "2025-12-31" } }';

      final out = gen.generate('RootData', json);

      // Top-level parts/imports
      expect(out, contains("import 'package:freezed_annotation/freezed_annotation.dart'"));
      expect(out, contains("part 'root_data.freezed.dart'"));

  // Root and nested classes
    expect(out, contains('class RootData'));
    expect(out, contains('class Company'));
    expect(out, contains('class Location'));
  expect(out, contains('class Department'));
  expect(out, contains('class Employee'));
  expect(out, contains('class Project'));
  expect(out, contains('class Campaign'));
  // Some keys like 'financials' may singularize to 'Financial'
  expect(out, anyOf(contains('class Financials'), contains('class Financial')));

    // Fields and list types (generator currently emits nullable fields)
  expect(out, contains('Company? company'));
  // Allow either Financials or Financial depending on singularization rules
  expect(out, anyOf(contains('Financials? financials'), contains('Financial? financials')));
  expect(out, contains('List<Department>? departments'));
  expect(out, contains('List<Employee>? employees'));
  expect(out, contains('List<String>? skills'));
    expect(out, anyOf(contains('String? projectName'), contains('String? projectName,')));
  expect(out, anyOf(contains('int? budget'), contains('double? budget')));
  expect(out, anyOf(contains('int? revenueLastQuarter'), contains('double? revenueLastQuarter')));
    });
  });
}
