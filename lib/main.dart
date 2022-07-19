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

const errorString = "Can't parse JSON";
final Uri _url = Uri.parse('https://fb.com/tungakanuiii');

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Freezed Generator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

String output = "";

List<String> classNames = [];

const String template = """
@freezed
class {className} with _\${className} {
    const factory {className}({
       {field}
    }) = _{className};

    factory {className}.fromJson(Map<String, dynamic> json) => _\${className}FromJson(json);
}\n
""";

String getNameIfExist(String className) {
  String copyName = className;
  if (classNames.contains(className)) {
    var x = 2;
    while (output.contains("$className$x")) {
      x++;
    }
    copyName = '$className$x';
  }
  return copyName.camelCase.titleCase;
}

void fromJsonToObject(Map<String, dynamic> json, String className) {
  String fields = "";

  for (var element in json.entries) {
    if (element.value == null) {
      if (element.key.contains('_') || element.key.startsWith(r"$")) {
        fields += '@JsonKey(name: "${element.key}") ';
      }
      fields +=
          'final dynamic ${element.key.replaceAll("\$", "").camelCase},\n';
    } else if (element.value is String) {
      if (element.key.contains('_') || element.key.startsWith(r"$")) {
        fields += '@JsonKey(name: "${element.key}") ';
      }
      fields +=
          'final String? ${element.key.replaceAll("\$", "").camelCase},\n';
    } else if (element.value is int) {
      if (element.key.contains('_') || element.key.startsWith(r"$")) {
        fields += '@JsonKey(name: "${element.key}") ';
      }
      fields += 'final int? ${element.key.replaceAll("\$", "").camelCase},\n';
    } else if (element.value is double) {
      if (element.key.contains('_') || element.key.startsWith(r"$")) {
        fields += '@JsonKey(name: "${element.key}") ';
      }
      fields +=
          'final double? ${element.key.replaceAll("\$", "").camelCase},\n';
    } else if (element.value is bool) {
      if (element.key.contains('_') || element.key.startsWith(r"$")) {
        fields += '@JsonKey(name: "${element.key}") ';
      }
      fields += 'final bool? ${element.key.replaceAll("\$", "").camelCase},\n';
    } else if (element.value is Map) {
      final name = getNameIfExist(element.key.camelCase.titleCase);
      if (element.key.contains('_') || element.key.startsWith(r"$")) {
        fields +=
            '@JsonKey(name: "${element.key}") final $name? ${element.key.replaceAll("\$", "").camelCase},\n';
      } else {
        fields +=
            'final $name? ${element.key.replaceAll("\$", "").camelCase},\n';
      }
      classNames.add(name);
      fromJsonToObject(element.value, name);
    } else if (element.value is List) {
      final name = getNameIfExist(element.key.camelCase.titleCase);
      if (element.key.contains('_') || element.key.startsWith(r"$")) {
        fields +=
            '@JsonKey(name: "${element.key}") final List<$name>? ${element.key.replaceAll("\$", "").camelCase},\n';
      } else {
        fields +=
            'final List<$name>? ${element.key.replaceAll("\$", "").camelCase},\n';
      }
      classNames.add(name);
      final List data = element.value as List<dynamic>;
      if (data.isNotEmpty) {
        fromJsonToObject(
          (element.value as List<dynamic>).first as Map<String, dynamic>,
          name,
        );
      } else {
        fromJsonToObject(
          {},
          name,
        );
      }
    }
  }

  output += template
      .replaceAll('{className}', className)
      .replaceAll('{field}', fields.replaceAll('"\$', '"\\\$'));
}

const Color greenColor = Color(0xFF06D6A0);

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String className = "";
  String input = "";

  late CodeController _codeController;

  @override
  void initState() {
    super.initState();
    _codeController = CodeController(
        text: "",
        language: yaml,
        theme: vs2015Theme,
        onChange: (v) {
          input = v;
          try {
            setState(() {
              process();
            });
          } catch (e) {
            setState(() {
              output = errorString;
            });
          }
        });
  }

  void process() {
    output = "";
    output += "import 'package:freezed_annotation/freezed_annotation.dart';\n";
    output += "part '${className.snakeCase}.freezed.dart';\n";
    output += "part '${className.snakeCase}.g.dart';\n\n";
    final js = jsonDecode(input);
    fromJsonToObject(js, className);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      floatingActionButton: CupertinoButton(
        onPressed: () {
          FlutterClipboard.copy(output);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Copied!",
                style: TextStyle(fontSize: 16),
              ),
              duration: Duration(seconds: 1),
              backgroundColor: greenColor,
            ),
          );
        },
        child: PhysicalModel(
          elevation: 16,
          color: greenColor,
          shadowColor: greenColor.withOpacity(0.6),
          shape: BoxShape.circle,
          child: Container(
            decoration: const BoxDecoration(
              color: greenColor,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(16),
            child: const Icon(
              Icons.copy,
              color: Colors.white,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    color: const Color(0xFF26547C),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: "Class name",
                            focusedBorder: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: greenColor, width: 1.0),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Color(0xFFFFD166), width: 1.0),
                            ),
                            hintStyle: TextStyle(color: Colors.white),
                          ),
                          onChanged: (v) {
                            setState(() {
                              classNames.clear();
                              classNames.add(v.titleCase);
                              className = v.titleCase;
                              process();
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: CodeField(
                            controller: _codeController,
                            expands: true,
                            maxLines: null,
                            minLines: null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: output == errorString
                      ? const Center(
                          child: Text(
                            errorString,
                            style: TextStyle(color: Color(0xFFEF476F)),
                          ),
                        )
                      : SingleChildScrollView(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: HighlightView(
                              output,
                              language: 'dart',
                              theme: atomOneLightTheme,
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: RichText(
              text: TextSpan(
                children: [
                  const TextSpan(
                    text: 'by @tungakanui ',
                    style: TextStyle(color: Colors.black),
                  ),
                  TextSpan(
                    text: 'Facebook',
                    style: const TextStyle(color: Colors.blue),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        if (!await launchUrl(_url)) {
                          throw 'Could not launch $_url';
                        }
                      },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
