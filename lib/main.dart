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
  final StringBuffer _output = StringBuffer();

  static const String _classTemplate = """
@freezed
class {className} with _\${className} {
  const factory {className}({
{fields}  }) = _{className};

  factory {className}.fromJson(Map<String, dynamic> json) => 
      _\${className}FromJson(json);
}
""";

  String generate(String className, String jsonString) {
    _classNames.clear();
    _output.clear();

    try {
      final json = jsonDecode(jsonString);
      if (json is! Map<String, dynamic>) {
        throw const FormatException('JSON must be an object');
      }

      _writeImports(className);
      _classNames.add(className);
      _generateClass(json, className);

      return _output.toString();
    } catch (e) {
      return kErrorString;
    }
  }

  void _writeImports(String className) {
    _output.writeln("import 'package:freezed_annotation/freezed_annotation.dart';");
    _output.writeln("part '${className.snakeCase}.freezed.dart';");
    _output.writeln("part '${className.snakeCase}.g.dart';");
    _output.writeln();
  }

  void _generateClass(Map<String, dynamic> json, String className) {
    final fields = <String>[];

    json.forEach((key, value) {
      final field = _processField(key, value);
      if (field != null) {
        fields.add(field);
      }
    });

    _output.writeln(_classTemplate
        .replaceAll('{className}', className)
        .replaceAll('{fields}', fields.join('\n')));
  }

  String? _processField(String key, dynamic value) {
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
      final nestedClassName = _getUniqueClassName(key);
      _generateClass(value, nestedClassName);
      return '$prefix $nestedClassName? $fieldName,';
    } else if (value is List) {
      return _processList(key, value, fieldName, prefix);
    }

    return null;
  }

  String _processList(String key, List list, String fieldName, String prefix) {
    if (list.isEmpty) {
      return '$prefix List<dynamic>? $fieldName,';
    }

    final firstItem = list.first;
    final listType = _getListType(firstItem, key);

    if (firstItem is Map<String, dynamic>) {
      // Merge all objects in the list to get all possible fields
      final mergedMap = _mergeListObjects(list);
      _generateClass(mergedMap, listType);
    }

    return '$prefix List<$listType>? $fieldName,';
  }

  Map<String, dynamic> _mergeListObjects(List list) {
    final merged = <String, dynamic>{};
    for (final item in list) {
      if (item is Map<String, dynamic>) {
        merged.addAll(item);
      }
    }
    return merged;
  }

  String _getListType(dynamic item, String key) {
    if (item is String) return 'String';
    if (item is int) return 'int';
    if (item is double) return 'double';
    if (item is bool) return 'bool';
    if (item is List) return 'List<dynamic>';
    if (item is Map) return _getUniqueClassName(key);
    return 'dynamic';
  }

  String _sanitizeFieldName(String key) {
    return key.replaceAll(r'$', '').camelCase;
  }

  bool _needsJsonKey(String key) {
    return key.contains('_') || key.startsWith(r'$');
  }

  String _getUniqueClassName(String baseName) {
    String className = baseName.camelCase.pascalCase;

    if (!_classNames.contains(className)) {
      _classNames.add(className);
      return className;
    }

    int counter = 2;
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
      _output = _generator.generate(className.pascalCase, jsonInput);
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
                color: kGreenColor.withOpacity(0.3),
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
          children: const [
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
          children: const [
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

// Extension for better string manipulation
extension StringExtension on String {
  String get pascalCase => camelCase.substring(0, 1).toUpperCase() + camelCase.substring(1);
}