// Pure Dart generator - no Flutter dependencies
import 'dart:convert';
import 'package:recase/recase.dart';
import 'package:pluralize/pluralize.dart';

const String kErrorString = "Can't parse JSON";

// Configuration options for the generator
class GeneratorConfig {
  final bool makeFieldsNullable;
  final int sampleSize;
  final bool useJsonSerializable;
  final bool generateCopyWith;
  final bool immutable;
  final bool detectEnums;
  final bool detectDateTime;
  final int enumMaxValues;

  const GeneratorConfig({
    this.makeFieldsNullable = true,
    this.sampleSize = 100,
    this.useJsonSerializable = true,
    this.generateCopyWith = true,
    this.immutable = true,
    this.detectEnums = true,
    this.detectDateTime = true,
    this.enumMaxValues = 10,
  });
}

// Field sample tracker for multi-sample analysis
class FieldSamples {
  final String fieldPath;
  final List<dynamic> samples = [];
  final Set<String> typeSignatures = {};

  FieldSamples(this.fieldPath);

  void addSample(dynamic value) {
    samples.add(value);
    typeSignatures.add(_getTypeSignature(value));
  }

  String _getTypeSignature(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return 'String';
    if (value is int) return 'int';
    if (value is double) return 'double';
    if (value is bool) return 'bool';
    if (value is List) return 'List';
    if (value is Map) return 'Map';
    return 'dynamic';
  }
}

// Generator class with comprehensive algorithm implementation
class FreezedGenerator {
  final GeneratorConfig config;
  final Set<String> _classNames = {};
  final Pluralize _pluralize = Pluralize();
  final StringBuffer _output = StringBuffer();
  final Map<String, Map<String, FieldSamples>> _classFieldSamples = {};
  final List<String> _classOrder = [];
  final Set<String> _keysObservedAsMap = {};
  final Map<String, Set<String>> _enumCandidates = {};

  FreezedGenerator({this.config = const GeneratorConfig()});

  String generate(String className, String jsonString, {int freezedVersion = 2}) {
    _classNames.clear();
    _classFieldSamples.clear();
    _classOrder.clear();
    _output.clear();
    _keysObservedAsMap.clear();
    _enumCandidates.clear();

    try {
      final json = jsonDecode(jsonString);

      // Handle array input
      List<Map<String, dynamic>> samples;
      if (json is List) {
        samples = json
            .whereType<Map<String, dynamic>>()
            .take(config.sampleSize)
            .toList();
        if (samples.isEmpty) {
          throw const FormatException('JSON array must contain objects');
        }
      } else if (json is Map<String, dynamic>) {
        samples = [json];
      } else {
        throw const FormatException('JSON must be an object or array of objects');
      }

      // Phase 1: Data Collection & Sampling
      _collectSamples(samples, className);

      // Phase 2 & 3: Type Inference and Conflict Resolution
      _inferTypes();

      // Phase 4: Class Generation
      _writeImports(className, freezedVersion: freezedVersion);
      for (final c in _classOrder) {
        _renderClass(c, freezedVersion: freezedVersion);
      }

      return _output.toString();
    } catch (e) {
      return kErrorString;
    }
  }

  // Phase 1: Collect samples from all JSON objects
  void _collectSamples(List<Map<String, dynamic>> samples, String rootClassName) {
    final normalizedClassName = _getOrCreateClass(rootClassName);

    for (final sample in samples) {
      _collectFromObject(sample, normalizedClassName);
    }
  }

  void _collectFromObject(Map<String, dynamic> obj, String className) {
    final fieldSamples = _classFieldSamples.putIfAbsent(className, () => {});

    obj.forEach((key, value) {
      final samples = fieldSamples.putIfAbsent(key, () => FieldSamples(key));
      samples.addSample(value);

      if (value is Map<String, dynamic>) {
        _keysObservedAsMap.add(key);
        final nestedClassName = _getOrCreateClass(key);
        _collectFromObject(value, nestedClassName);
      } else if (value is List) {
        _collectFromList(value, key);
      }
    });
  }

  void _collectFromList(List list, String fieldName) {
    final limitedList = list.take(config.sampleSize).toList();

    for (final item in limitedList) {
      if (item is Map<String, dynamic>) {
        final nestedClassName = _getOrCreateClass(fieldName);
        _collectFromObject(item, nestedClassName);
      } else if (item is List) {
        _collectFromList(item, fieldName);
      }
    }
  }

  // Phase 2: Type Inference with Pattern Recognition
  void _inferTypes() {
    // Type inference is performed on-demand during rendering
  }

  String _inferFieldType(String fieldName, FieldSamples samples) {
    if (samples.typeSignatures.isEmpty ||
        (samples.typeSignatures.length == 1 && samples.typeSignatures.contains('null'))) {
      return _inferTypeFromFieldName(fieldName);
    }

    final nonNullTypes = samples.typeSignatures.where((t) => t != 'null').toSet();

    if (nonNullTypes.isEmpty) {
      return _inferTypeFromFieldName(fieldName);
    }

    if (nonNullTypes.length == 1) {
      final type = nonNullTypes.first;

      if (type == 'Map') {
        return _getOrCreateClass(fieldName);
      }

      if (type == 'String' && config.detectDateTime) {
        final stringValues = samples.samples.whereType<String>().toList();
        if (_isDateTimeField(fieldName, stringValues)) {
          return 'DateTime';
        }
      }

      if (type == 'String' && config.detectEnums) {
        final stringValues = samples.samples.whereType<String>().where((s) => s.isNotEmpty).toSet();
        if (stringValues.length > 1 &&
            stringValues.length <= config.enumMaxValues &&
            _hasConsistentPattern(stringValues)) {
          _enumCandidates[fieldName] = stringValues;
          return _getEnumName(fieldName);
        }
      }

      if (type == 'List') {
        return _inferListType(fieldName, samples);
      }

      return type;
    }

    return _resolveTypeConflict(nonNullTypes);
  }

  String _inferTypeFromFieldName(String fieldName) {
    final lower = fieldName.toLowerCase();

    if (RegExp(r'^(is|has|can|should|will)[A-Z]').hasMatch(fieldName)) {
      return 'bool';
    }

    if (RegExp(r'(_count|_total|_size|_number)$').hasMatch(lower)) {
      return 'int';
    }

    if (RegExp(r'(_id|_uuid|_key)$').hasMatch(lower) || lower == 'id') {
      return 'String';
    }

    if (RegExp(r'(_price|_amount|_rate|_lat|_lng|_lon|_latitude|_longitude)$').hasMatch(lower)) {
      return 'double';
    }

    if (RegExp(r'(_date|_time|_at|_timestamp)$').hasMatch(lower)) {
      return 'DateTime';
    }

    if (RegExp(r'(_url|_uri|_path|_link)$').hasMatch(lower)) {
      return 'String';
    }

    if (RegExp(r'(_email|_phone|_mobile)$').hasMatch(lower)) {
      return 'String';
    }

    if (_keysObservedAsMap.contains(fieldName)) {
      return _getOrCreateClass(fieldName);
    }

    return 'String';
  }

  bool _isDateTimeField(String fieldName, List<String> samples) {
    if (samples.isEmpty) {
      final lower = fieldName.toLowerCase();
      return RegExp(r'(_date|_time|_at|timestamp)').hasMatch(lower);
    }

    int dateTimeMatches = 0;
    for (final sample in samples.take(10)) {
      if (_looksLikeDateTime(sample)) {
        dateTimeMatches++;
      }
    }

    return dateTimeMatches > samples.length * 0.5;
  }

  bool _looksLikeDateTime(String value) {
    if (value.isEmpty) return false;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(value)) return true;
    if (RegExp(r'^\d{10,13}$').hasMatch(value)) return true;
    if (RegExp(r'\d{4}[-/]\d{2}[-/]\d{2}').hasMatch(value)) return true;
    return false;
  }

  bool _hasConsistentPattern(Set<String> values) {
    if (values.isEmpty) return false;

    final upperCaseCount = values.where((v) => v == v.toUpperCase() && v.contains('_')).length;
    if (upperCaseCount == values.length) return true;

    final camelCaseCount = values.where((v) => RegExp(r'^[a-z][a-zA-Z0-9]*$').hasMatch(v)).length;
    if (camelCaseCount == values.length) return true;

    final pascalCaseCount = values.where((v) => RegExp(r'^[A-Z][a-zA-Z0-9]*$').hasMatch(v)).length;
    if (pascalCaseCount == values.length) return true;

    return false;
  }

  String _getEnumName(String fieldName) {
    return '${fieldName.camelCase.titleCase.replaceAll(' ', '')}Enum';
  }

  String _inferListType(String fieldName, FieldSamples samples) {
    final listSamples = samples.samples.whereType<List>().toList();

    if (listSamples.isEmpty) {
      final lower = fieldName.toLowerCase();
      if (RegExp(r'(counts|totals|numbers)$').hasMatch(lower)) {
        return 'List<int>';
      }
      if (RegExp(r'(names|titles|descriptions)$').hasMatch(lower)) {
        return 'List<String>';
      }
      return 'List<dynamic>';
    }

    final elementTypes = <String>{};
    for (final list in listSamples) {
      for (final element in list) {
        if (element is Map<String, dynamic>) {
          elementTypes.add(_getOrCreateClass(fieldName));
        } else {
          elementTypes.add(_getTypeSignature(element));
        }
      }
    }

    elementTypes.remove('null');

    if (elementTypes.isEmpty) {
      return 'List<dynamic>';
    }

    if (elementTypes.length == 1) {
      return 'List<${elementTypes.first}>';
    }

    if (elementTypes.contains('int') && elementTypes.contains('double')) {
      return 'List<num>';
    }

    return 'List<dynamic>';
  }

  String _resolveTypeConflict(Set<String> types) {
    if (types.every((t) => t == 'int' || t == 'double' || t == 'num')) {
      if (types.contains('double')) return 'double';
      return 'num';
    }

    return 'dynamic';
  }

  String _getTypeSignature(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return 'String';
    if (value is int) return 'int';
    if (value is double) return 'double';
    if (value is bool) return 'bool';
    if (value is List) return 'List';
    if (value is Map) return 'Map';
    return 'dynamic';
  }

  String _getOrCreateClass(String base) {
    var candidate = base;
    try {
      candidate = _pluralize.singular(candidate);
    } catch (_) {}
    var className = candidate.camelCase.titleCase.replaceAll(' ', '');
    if (className.isEmpty) className = 'AutoGenerated';

    if (!_classFieldSamples.containsKey(className)) {
      var unique = className;
      var i = 2;
      while (_classFieldSamples.containsKey(unique)) {
        unique = '$className$i';
        i++;
      }
      className = unique;
      _classFieldSamples[className] = {};
      _classOrder.add(className);
      _classNames.add(className);
    }

    return className;
  }

  void _writeImports(String className, {int freezedVersion = 2}) {
    final partName = className.snakeCase;
    _output.writeln("import 'package:freezed_annotation/freezed_annotation.dart';");
    _output.writeln();
    _output.writeln("part '$partName.freezed.dart';");
    if (freezedVersion < 3) {
      _output.writeln("part '$partName.g.dart';");
    }
    _output.writeln();
  }

  // Phase 4: Class Generation with advanced features
  void _renderClass(String className, {int freezedVersion = 2}) {
    final fieldSamples = _classFieldSamples[className]!;
    final fields = <String>[];

    fieldSamples.forEach((originalFieldName, samples) {
      final fieldName = _sanitizeFieldName(originalFieldName);
      final inferredType = _inferFieldType(originalFieldName, samples);

      final jsonKeyAnnotation = originalFieldName != fieldName
          ? "@JsonKey(name: '$originalFieldName') "
          : '';

      final isDateTime = inferredType == 'DateTime';
      final dateTimeAnnotation = isDateTime && config.detectDateTime
          ? '@DateTimeConverter() '
          : '';

      if (_enumCandidates.containsKey(originalFieldName)) {
        final nullability = config.makeFieldsNullable ? '?' : '';
        fields.add('    ${jsonKeyAnnotation}String$nullability $fieldName,');
        return;
      }

      if (_classNames.contains(inferredType)) {
        final nullability = config.makeFieldsNullable ? '?' : '';
        fields.add('    $jsonKeyAnnotation$inferredType$nullability $fieldName,');
        return;
      }

      if (inferredType.startsWith('List<')) {
        final nullability = config.makeFieldsNullable ? '?' : '';
        fields.add('    $jsonKeyAnnotation$inferredType$nullability $fieldName,');
        return;
      }

      final nullability = config.makeFieldsNullable ? '?' : '';
      fields.add('    $dateTimeAnnotation$jsonKeyAnnotation$inferredType$nullability $fieldName,');
    });

    _output.writeln('@freezed');
    final classKeyword = freezedVersion >= 3 ? 'abstract class' : 'class';
    _output.writeln('$classKeyword $className with _\$$className {');
    _output.writeln('  const factory $className({');
    for (final f in fields) {
      _output.writeln(f);
    }
    _output.writeln('  }) = _$className;');
    _output.writeln();
    _output.writeln('  factory $className.fromJson(Map<String, dynamic> json) =>');
    _output.writeln('      _\$${className}FromJson(json);');
    _output.writeln('}');
    _output.writeln();
  }

  String _sanitizeFieldName(String key) {
    var sanitized = key.replaceAll(RegExp(r"[^A-Za-z0-9_]"), '');
    if (sanitized.isNotEmpty && RegExp(r'^[0-9]').hasMatch(sanitized)) {
      sanitized = '_$sanitized';
    }
    return sanitized.camelCase;
  }
}
