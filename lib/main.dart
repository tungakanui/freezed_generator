import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:recase/recase.dart';

void main() {
  runApp(const MyApp());
}

const errorString = "JSON????";

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

String output = "";

const String template = """
@freezed
class {className} with _\${className} {
    const factory {className}({
       {field}
    }) = _{className};

    factory {className}.fromJson(Map<String, dynamic> json) => _\${className}FromJson(json);
}
""";

void fromJsonToObject(Map<String, dynamic> json, String className) {
  String fields = "";
  for (var element in json.entries) {
    if (element.value is String) {
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
      if (element.key.contains('_') || element.key.startsWith(r"$")) {
        fields +=
            '@JsonKey(name: "${element.key}") final ${element.key.camelCase.titleCase}? ${element.key.replaceAll("\$", "").camelCase},\n';
      } else {
        fields +=
            'final ${element.key.camelCase.titleCase}? ${element.key.replaceAll("\$", "").camelCase},\n';
      }
      fromJsonToObject(
          element.value, element.key.replaceAll("\$", "").camelCase.titleCase);
    } else if (element.value is List) {
      if (element.key.contains('_') || element.key.startsWith(r"$")) {
        fields +=
            '@JsonKey(name: "${element.key}") final List<${element.key.camelCase.titleCase}>? ${element.key.replaceAll("\$", "").camelCase},\n';
      } else {
        fields +=
            'final List<${element.key.camelCase.titleCase}>? ${element.key.replaceAll("\$", "").camelCase},\n';
      }
      fromJsonToObject((element.value as List<Map<String, dynamic>>).first,
          element.key.replaceAll("\$", "").camelCase);
    }
  }

  output += template
      .replaceAll('{className}', className)
      .replaceAll('{field}', fields.replaceAll('"\$', '"\\\$'));
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String className = "";
  String input = "";

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
      body: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(hintText: "Class name"),
                    onChanged: (v) {
                      setState(() {
                        className = v;
                        process();
                      });
                    },
                  ),
                  Expanded(
                    child: TextFormField(
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      decoration: const InputDecoration(hintText: "Json"),
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
                    ),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: SelectableText(
                  output,
                  style: TextStyle(
                    color: output == errorString ? Colors.red : Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
