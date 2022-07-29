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
  String copyName = titleKey(className.camelCase.titleCase);
  if (classNames.contains(copyName)) {
    var x = 2;
    while (output.contains("$copyName$x")) {
      x++;
    }
    copyName = '$copyName$x';
  }
  return copyName;
}

void fromJsonToObject(Map<String, dynamic> json, String className) {
  String fields = "";

  for (var key in json.keys) {
    print(key);
    if (json[key] == null) {
      if (key.contains('_') || key.startsWith(r"$")) {
        fields += '@JsonKey(name: "$key") ';
      }
      fields +=
          'final dynamic ${key.replaceAll("\$", "").camelCase},\n';
    } else if (json[key] is String) {
      if (key.contains('_') || key.startsWith(r"$")) {
        fields += '@JsonKey(name: "$key") ';
      }
      fields +=
          'final String? ${key.replaceAll("\$", "").camelCase},\n';
    } else if (json[key] is int) {
      if (key.contains('_') || key.startsWith(r"$")) {
        fields += '@JsonKey(name: "$key") ';
      }
      fields += 'final int? ${key.replaceAll("\$", "").camelCase},\n';
    } else if (json[key] is double) {
      if (key.contains('_') || key.startsWith(r"$")) {
        fields += '@JsonKey(name: "$key") ';
      }
      fields +=
          'final double? ${key.replaceAll("\$", "").camelCase},\n';
    } else if (json[key] is bool) {
      if (key.contains('_') || key.startsWith(r"$")) {
        fields += '@JsonKey(name: "$key") ';
      }
      fields += 'final bool? ${key.replaceAll("\$", "").camelCase},\n';
    } else if (json[key] is Map) {

      final name = getNameIfExist(key);
      if (key.contains('_') || key.startsWith(r"$")) {
        fields +=
            '@JsonKey(name: "$key") final $name? ${key.replaceAll("\$", "").camelCase},\n';
      } else {
        fields +=
            'final $name? ${key.replaceAll("\$", "").camelCase},\n';
      }
      classNames.add(name);
      fromJsonToObject(json[key], name);
    } else if (json[key] is List) {
      final name = getNameIfExist(key);
      if (json[key].first is String) {
        if (key.contains('_') || key.startsWith(r"$")) {
          fields +=
          '@JsonKey(name: "$key") final List<String>? ${key.replaceAll("\$", "").camelCase},\n';
        } else {
          fields +=
          'final List<String>? ${key.replaceAll("\$", "").camelCase},\n';
        }
      } else if (json[key].first is int) {
        if (key.contains('_') || key.startsWith(r"$")) {
          fields +=
          '@JsonKey(name: "$key") final List<int>? ${key.replaceAll("\$", "").camelCase},\n';
        } else {
          fields +=
          'final List<int>? ${key.replaceAll("\$", "").camelCase},\n';
        }
      } else if (json[key].first is double) {
        if (key.contains('_') || key.startsWith(r"$")) {
          fields +=
          '@JsonKey(name: "$key") final List<double>? ${key.replaceAll("\$", "").camelCase},\n';
        } else {
          fields +=
          'final List<double>? ${key.replaceAll("\$", "").camelCase},\n';
        }
      } else if (json[key].first is bool) {
        if (key.contains('_') || key.startsWith(r"$")) {
          fields +=
          '@JsonKey(name: "$key") final List<bool>? ${key.replaceAll("\$", "").camelCase},\n';
        } else {
          fields +=
          'final List<bool>? ${key.replaceAll("\$", "").camelCase},\n';
        }
      } else if (json[key].first is List) {
        if (key.contains('_') || key.startsWith(r"$")) {
          fields +=
          '@JsonKey(name: "$key") final List<List<dynamic>>? ${key.replaceAll("\$", "").camelCase},\n';
        } else {
          fields +=
          'final List<List<dynamic>>? ${key.replaceAll("\$", "").camelCase},\n';
        }
      } else if (json[key].first is Map) {
        final name = getNameIfExist(key.camelCase.titleCase);
        if (key.contains('_') || key.startsWith(r"$")) {
          fields +=
          '@JsonKey(name: "$key") final List<$name>? ${key.replaceAll("\$", "").camelCase},\n';
        } else {
          fields +=
          'final List<$name>? ${key.replaceAll("\$", "").camelCase},\n';
        }
        classNames.add(name);
        final List data = json[key] as List<dynamic>;
        if (data.isNotEmpty) {
          fromJsonToObject(
            (json[key] as List<dynamic>).first as Map<String, dynamic>,
            name,
          );
        } else {
          fromJsonToObject(
            {},
            name,
          );
        }
      }

      // if (key.contains('_') || key.startsWith(r"$")) {
      //   fields +=
      //       '@JsonKey(name: "$key") final List<$name>? ${key.replaceAll("\$", "").camelCase},\n';
      // } else {
      //   fields +=
      //       'final List<$name>? ${key.replaceAll("\$", "").camelCase},\n';
      // }
      // classNames.add(titleKey(name));
      // final List data = json[key] as List<dynamic>;
      // if (data.isNotEmpty) {
      //   fromJsonToObject(
      //     (json[key] as List<dynamic>).first as Map<String, dynamic>,
      //     titleKey(name),
      //   );
      // } else {
      //   fromJsonToObject(
      //     {},
      //     titleKey(name),
      //   );
      // }
    }
  }

  output += template
      .replaceAll('{className}', className)
      .replaceAll('{field}', fields.replaceAll('"\$', '"\\\$'));
}

const Color greenColor = Color(0xFF06D6A0);

String titleKey(String val) => val.titleCase.split(" ").join();

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
    if (input.isEmpty) return;
    classNames = [];
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
                              classNames.add(titleKey(v));
                              className = titleKey(v);
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
