import 'dart:async';

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

// Export and import the generator with advanced algorithm
export 'generator.dart';
import 'generator.dart';

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