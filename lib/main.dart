import 'dart:async';
import 'dart:convert';

import 'package:clipboard/clipboard.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:highlight/languages/yaml.dart';
import 'package:recase/recase.dart';
import 'package:pluralize/pluralize.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

// Constants
const String kErrorString = "Can't parse JSON";
const Color kGreenColor = Color(0xFF06D6A0);
const Color kBlueColor = Color(0xFF26547C);
const Color kYellowColor = Color(0xFFFFD166);
const Color kRedColor = Color(0xFFEF476F);

final Uri _fbUrl = Uri.parse('https://fb.com/tungakanuiii');

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Freezed Generator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

// Model classes for better type safety
class FreezedClass {
  final String name;
  final List<FreezedField> fields;

  FreezedClass({required this.name, required this.fields});
}

class FreezedField {
  final String name;
  final String type;
  final bool isNullable;
  final String? jsonKey;

  FreezedField({
    required this.name,
    required this.type,
    this.isNullable = true,
    this.jsonKey,
  });
}

// Generator class with optimized logic
class FreezedGenerator {
  final Set<String> _classNames = {};
  final Map<String, String> _signatureToClass = {};
  final Pluralize _pluralize = Pluralize();
  final StringBuffer _output = StringBuffer();

  // Build class source safely (avoid interpolation/escape issues in templates)

  String generate(String className, String jsonString, {int freezedVersion = 2}) {
    _classNames.clear();
    _output.clear();

    try {
      final json = jsonDecode(jsonString);
      if (json is! Map<String, dynamic>) {
        throw const FormatException('JSON must be an object');
      }

  _writeImports(className, freezedVersion: freezedVersion);
  _classNames.add(className);
  _generateClass(json, className, freezedVersion: freezedVersion);

      return _output.toString();
    } catch (e) {
      return kErrorString;
    }
  }

  void _writeImports(String className, {int freezedVersion = 2}) {
    // minimize repeated snakeCase computation
    final partName = className.snakeCase;
    _output.writeln("import 'package:freezed_annotation/freezed_annotation.dart';");
    _output.writeln("part '$partName.freezed.dart';");
    // Freezed v3 moves away from generating .g.dart files for JSON if
    // using the new codegen; omit the g.dart part when generating for v3.
    if (freezedVersion < 3) {
      _output.writeln("part '$partName.g.dart';");
    }
    _output.writeln();
  }

  void _generateClass(Map<String, dynamic> json, String className, {int freezedVersion = 2}) {
    final fields = <String>[];

    json.forEach((key, value) {
      final field = _processField(key, value, freezedVersion: freezedVersion);
      if (field != null) fields.add(field);
    });

    // Build class source directly to avoid escaping/interpolation issues.
    // Use '\$' to emit a literal dollar sign in the generated Dart code and
    // concatenate/interpolate the runtime className where needed.
  _output.writeln('@freezed');
  // Freezed v3 requires classes using factory constructors to be declared
  // with a keyword: `abstract` (or `sealed`). We default to `abstract` for v3
  // and keep `class` for v2 to maintain compatibility.
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
  }

  String? _processField(String key, dynamic value, {int freezedVersion = 2}) {
    final fieldName = _sanitizeFieldName(key);
    final needsJsonKey = _needsJsonKey(key);
    final prefix = needsJsonKey ? '    @JsonKey(name: "$key") ' : '    ';

    // Handle different types
    if (value == null) {
      return '$prefix dynamic $fieldName,';
    } else if (value is String) {
      return '$prefix String? $fieldName,';
    } else if (value is num) {
      final type = value is int && !value.toString().contains('.') ? 'int' : 'double';
      return '$prefix $type? $fieldName,';
    } else if (value is bool) {
      return '$prefix bool? $fieldName,';
    } else if (value is Map<String, dynamic>) {
      final nestedClassName = _getClassNameForMap(value, key, freezedVersion);
      return '$prefix $nestedClassName? $fieldName,';
    } else if (value is List) {
      return _processList(key, value, fieldName, prefix, freezedVersion);
    }

    return null;
  }

  String _processList(String key, List list, String fieldName, String prefix, int freezedVersion) {
    if (list.isEmpty) return '$prefix List<dynamic>? $fieldName,';

    // Infer a single best-effort element type from all items in the list
    final elementType = _getListType(list, key, freezedVersion);

    return '$prefix List<$elementType>? $fieldName,';
  }

  String _getListType(List list, String key, int freezedVersion) {
    if (list.isEmpty) return 'dynamic';

    // Track discovered primitive types, nested list types and maps
    final primitiveTypes = <String>{};
    final nestedInnerTypes = <String>{};
    Map<String, dynamic> mergedMap = {};
    var sawMap = false;

    for (final item in list) {
      if (item == null) continue;

      if (item is String) {
        primitiveTypes.add('String');
        continue;
      }

      if (item is int) {
        primitiveTypes.add('int');
        continue;
      }

      if (item is double) {
        primitiveTypes.add('double');
        continue;
      }

      if (item is bool) {
        primitiveTypes.add('bool');
        continue;
      }

      if (item is List) {
        // Recursively infer inner type
        final inner = _getListType(item, key, freezedVersion);
        nestedInnerTypes.add(inner);
        continue;
      }

      if (item is Map<String, dynamic>) {
        sawMap = true;
        mergedMap.addAll(item);
        continue;
      }

      // Fallback for unknown types
      primitiveTypes.add('dynamic');
    }

    // If we found maps and nothing else, generate a class from merged fields
    if (sawMap && primitiveTypes.isEmpty && nestedInnerTypes.isEmpty) {
      // Merge map fields and deduplicate by structure/signature
      final className = _getClassNameForMap(mergedMap, key, freezedVersion);
      return className;
    }

    // Mixed maps with other types -> fallback to dynamic
    if (sawMap && (primitiveTypes.isNotEmpty || nestedInnerTypes.isNotEmpty)) {
      return 'dynamic';
    }

    // If we have nested list types, try to unify them
    if (nestedInnerTypes.isNotEmpty) {
      if (nestedInnerTypes.length == 1) {
        final inner = nestedInnerTypes.first;
        return 'List<$inner>';
      }
      return 'List<dynamic>';
    }

    // Handle primitive types unification
    if (primitiveTypes.isNotEmpty) {
      // int + double -> double
      if (primitiveTypes.length == 2 && primitiveTypes.contains('int') && primitiveTypes.contains('double')) {
        return 'double';
      }

      if (primitiveTypes.length == 1) return primitiveTypes.first;

      // Multiple different primitive types -> dynamic
      return 'dynamic';
    }

    // Default fallback
    return 'dynamic';
  }

  String _signatureForValue(dynamic v) {
    if (v == null) return 'null';
    if (v is String) return 'String';
    if (v is int) return 'int';
    if (v is double) return 'double';
    if (v is bool) return 'bool';
    if (v is List) {
      final inner = <String>{};
      for (final item in v) {
        inner.add(_signatureForValue(item));
      }
      if (inner.isEmpty) return 'List<dynamic>';
      if (inner.length == 1) return 'List<${inner.first}>';
      return 'List<dynamic>';
    }
    if (v is Map<String, dynamic>) {
      return 'Map(${_signatureForMap(v)})';
    }
    return 'dynamic';
  }

  String _signatureForMap(Map<String, dynamic> map) {
    final keys = map.keys.toList()..sort();
    final parts = <String>[];
    for (final k in keys) {
      final sig = _signatureForValue(map[k]);
      parts.add('$k:$sig');
    }
    return parts.join(';');
  }

  String _getClassNameForMap(Map<String, dynamic> map, String baseName, int freezedVersion) {
    final sig = _signatureForMap(map);
    if (_signatureToClass.containsKey(sig)) {
      return _signatureToClass[sig]!;
    }

    final candidate = _getUniqueClassName(baseName);
    _signatureToClass[sig] = candidate;
    _generateClass(map, candidate, freezedVersion: freezedVersion);
    return candidate;
  }

  String _sanitizeFieldName(String key) {
    // Remove characters that can't appear in Dart identifiers and convert to camelCase
    var sanitized = key.replaceAll(RegExp(r"[^A-Za-z0-9_]"), '');
    // If name starts with digit, prefix with underscore
    if (sanitized.isNotEmpty && RegExp(r'^[0-9]').hasMatch(sanitized)) {
      sanitized = '_$sanitized';
    }
    return sanitized.camelCase;
  }

  bool _needsJsonKey(String key) {
    // Need explicit JsonKey if the key isn't a valid Dart identifier or contains underscore
    return RegExp(r'[^A-Za-z0-9]').hasMatch(key) || key.contains('_') || key.startsWith(r'$');
  }

  String _getUniqueClassName(String baseName) {
    // Use the pluralize package to get a reasonable singular form for class names.
    var candidate = baseName;
    try {
      candidate = _pluralize.singular(candidate);
    } catch (_) {
      // Fallback to original heuristics if pluralize fails for any reason
      candidate = baseName;
    }

    var className = candidate.camelCase.titleCase.replaceAll(' ', '');
    if (className.isEmpty) className = 'AutoGenerated';

    if (!_classNames.contains(className)) {
      _classNames.add(className);
      return className;
    }

    var counter = 2;
    while (_classNames.contains('$className$counter')) {
      counter++;
    }

    final uniqueName = '$className$counter';
    _classNames.add(uniqueName);
    return uniqueName;
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _classNameController = TextEditingController();
  late final CodeController _codeController;
  final _generator = FreezedGenerator();

  String _output = '';
  Timer? _debounceTimer;
  int _freezedVersion = 2; // default to v2 for backward compatibility
  

  @override
  void initState() {
    super.initState();
    _codeController = CodeController(
      text: '',
      language: yaml,
    );
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _codeController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

 

  void _generateCode() {
    final className = _classNameController.text.trim();
    final jsonInput = _codeController.text.trim();

    if (className.isEmpty || jsonInput.isEmpty) {
      setState(() => _output = '');
      return;
    }

    setState(() {
      _output = _generator.generate(className.titleCase.replaceAll(' ', ''), jsonInput, freezedVersion: _freezedVersion);
    });
  }

  void _onInputChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), _generateCode);
  }

  

  void _copyToClipboard() {
    if (_output.isEmpty || _output == kErrorString) return;

    FlutterClipboard.copy(_output);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied!', style: TextStyle(fontSize: 16)),
        duration: Duration(seconds: 1),
        backgroundColor: kGreenColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _launchUrl() async {
    if (!await launchUrl(_fbUrl)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch URL'),
            backgroundColor: kRedColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      floatingActionButton: _buildCopyButton(),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildInputPanel()),
                Expanded(child: _buildOutputPanel()),
              ],
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildCopyButton() {
    return AnimatedOpacity(
      opacity: _output.isNotEmpty && _output != kErrorString ? 1.0 : 0.3,
      duration: const Duration(milliseconds: 200),
      child: CupertinoButton(
        onPressed: _output.isNotEmpty && _output != kErrorString ? _copyToClipboard : null,
        child: Container(
          decoration: BoxDecoration(
            color: kGreenColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: kGreenColor.withAlpha(77),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: const Icon(Icons.copy, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildInputPanel() {
    return Container(
      color: kBlueColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _classNameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Class name',
              labelStyle: TextStyle(color: Colors.white70),
              hintText: 'e.g., User, Product, Order',
              hintStyle: TextStyle(color: Colors.white30),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: kGreenColor, width: 2.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: kYellowColor, width: 1.0),
              ),
              prefixIcon: Icon(Icons.class_, color: Colors.white54),
            ),
            onChanged: (_) => _onInputChanged(),
          ),
          const SizedBox(height: 8),
          // Freezed version selector
          Row(
            children: [
              const Text('Freezed version:', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: _freezedVersion,
                dropdownColor: kBlueColor,
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 2, child: Text('v2')),
                  DropdownMenuItem(value: 3, child: Text('v3')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _freezedVersion = v;
                  });
                  _onInputChanged();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(8),
              ),
              child: CodeTheme(
                data: const CodeThemeData(styles: vs2015Theme),
                child: CodeField(
                  controller: _codeController,
                  onChanged: (_) => _onInputChanged(),
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textStyle: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputPanel() {
    if (_output == kErrorString) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: kRedColor, size: 48),
            SizedBox(height: 16),
            Text(
              kErrorString,
              style: TextStyle(color: kRedColor, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Please check your JSON syntax',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_output.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.code, color: Colors.grey, size: 48),
            SizedBox(height: 16),
            Text(
              'Enter a class name and paste your JSON',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.grey[50],
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              children: const [
                Icon(Icons.check_circle, color: kGreenColor, size: 20),
                SizedBox(width: 8),
                Text(
                  'Generated Freezed Classes',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: HighlightView(
                _output,
                language: 'dart',
                textSelectable: true,
                theme: atomOneLightTheme,
                padding: const EdgeInsets.all(16),
                textStyle: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            const TextSpan(
              text: 'Created by @tungakanui · ',
              style: TextStyle(color: Colors.black87),
            ),
            TextSpan(
              text: 'Facebook',
              style: const TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()..onTap = _launchUrl,
            ),
          ],
        ),
      ),
    );
  }
}