import 'dart:convert';

import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:highlight/languages/yaml.dart';
import 'package:recase/recase.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

const errorString = "Can't parse JSON";
final Uri _url = Uri.parse('https://www.facebook.com/phamdanh.quyen/');

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Json To Dart Generator',
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
class {className} extends Equatable {
  {finalField}
  const {className}({
    {field}
  });

  factory {className}.fromJson(Map<String, dynamic> json) => _\${className}FromJson(json);

  

  @override
  List<Object?> get props {
    return [
      {props}
    ];
  }
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
  String finalFields = "";
  String props = "";

  for (var key in json.keys) {
    print(key);
    if (json[key] == null) {
      finalFields += 'final dynamic ${key.camelCase};\n';
      fields += 'this.${key.camelCase},\n';
    } else if (json[key] is String) {
      finalFields += 'final String? ${key.camelCase};\n';
      fields += 'this.${key.camelCase},\n';
    } else if (json[key] is int) {
      finalFields += 'final num? ${key.camelCase};\n';
      fields += 'this.${key.camelCase},\n';
    } else if (json[key] is double) {
      finalFields += 'final num? ${key.camelCase};\n';
      fields += 'this.${key.camelCase},\n';
    } else if (json[key] is bool) {
      finalFields += 'final bool? ${key.camelCase};\n';
      fields += 'this.${key.camelCase},\n';
    } else if (json[key] is Map) {
      final name = getNameIfExist(key);
      finalFields += 'final $name? ${key.camelCase};\n';
      fields += 'this.${key.camelCase},\n';
      classNames.add(name);
      fromJsonToObject(json[key], name);
    } else if (json[key] is List) {
      if ((json[key] as List).isEmpty) {
        finalFields += 'final List<dynamic>? ${key.camelCase};\n';
        fields += 'this.${key.camelCase},\n';
      } else if (json[key].first is String) {
        finalFields += 'final List<String>? ${key.camelCase};\n';
        fields += 'this.${key.camelCase},\n';
      } else if (json[key].first is int) {
        finalFields += 'final List<num>? ${key.camelCase};\n';

        fields += 'this.${key.camelCase},\n';
      } else if (json[key].first is double) {
        finalFields += 'final List<num>? ${key.camelCase};\n';

        fields += 'this.${key.camelCase},\n';
      } else if (json[key].first is bool) {
        finalFields += 'final List<bool>? ${key.camelCase};\n';

        fields += 'this.${key.camelCase},\n';
      } else if (json[key].first is List) {
        finalFields += 'final List<List<dynamic>>? ${key.camelCase};\n';
        fields += 'this.${key.camelCase},\n';
      } else if (json[key].first is Map) {
        final name = getNameIfExist(key.camelCase.titleCase);
        finalFields += 'final List<$name>? ${key.camelCase};\n';
        fields += 'this.${key.camelCase},\n';
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
    }
    props += '${key.camelCase},\n';
  }

  output += template
      .replaceAll('{className}', className)
      .replaceAll('{finalField}', finalFields)
      .replaceAll('{props}', props)
      .replaceAll('{field}', fields);
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
  late CodeController _outPutController;

  @override
  void initState() {
    super.initState();
    _codeController = CodeController(
      text: "",
      language: yaml,
      patternMap: vs2015Theme,
      stringMap: vs2015Theme,
    );
    _outPutController = CodeController(
      text: "",
      language: yaml,
      patternMap: vs2015Theme,
      stringMap: vs2015Theme,
    );
  }

  void process() {
    if (input.isEmpty) return;
    classNames = [];
    output = "";
    output += "import 'package:equatable/equatable.dart';\n\n";
    final js = jsonDecode(input);
    fromJsonToObject(js, className);
    _outPutController.text = output;
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
                            onChanged: (v) {
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
                            },
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
                        : CodeField(
                            controller: _outPutController,
                            readOnly: true,
                            expands: true,
                            maxLines: null,
                            minLines: null,
                            smartQuotesType: SmartQuotesType.enabled,
                          )
                    // : SingleChildScrollView(
                    //     child: Padding(
                    //       padding:
                    //           const EdgeInsets.symmetric(horizontal: 16.0),
                    //       child: HighlightView(
                    //         output,
                    //         language: 'Dart',
                    //         theme: atomOneLightTheme,
                    //         padding: const EdgeInsets.all(12),
                    //       ),
                    //     ),
                    //   ),
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
                    text: 'by @quyenpham ',
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
