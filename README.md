# Freezed Generator

A small Flutter utility that generates `freezed` model classes from a pasted JSON object.

Features
- Paste JSON and a root class name to generate Freezed model classes.
- Smart inference for lists, nested objects, and primitive types.
- Dropdown to choose target Freezed version (v2 or v3). For v3 the generator emits `abstract class` and omits the `.g.dart` part file.
- Copy generated output to clipboard and open a selectable view for easy copying.
- Unit tests covering list inference and nested generation.

Prerequisites
- Flutter SDK (stable) installed and on your PATH.
- A browser or device to run the Flutter app.

Quick start

1. Install dependencies

```bash
cd /path/to/freezed_generator
flutter pub get
```

2. Run the app (web)

```bash
flutter run -d chrome
```

Or run on a connected device/emulator:

```bash
flutter run
```

3. Use the app
- Enter a Class name in the top-left input (e.g. `RootData`).
- Paste/enter your JSON in the editor below the class name.
- Select the Freezed version (`v2` or `v3`) from the dropdown. Default is `v2`.
	- v2: generator emits `class` and includes a `part '<name>.g.dart';` directive.
	- v3: generator emits `abstract class` and omits the `.g.dart` part by default.
- Generated classes appear on the right. Use the copy button to copy the generated code, or click the open icon in the header to open a selectable view and copy parts of the output.

Testing

Run unit tests:

```bash
flutter test
```

Notes and limitations

- The generator heuristically singularizes plural JSON keys when creating nested class names (e.g. `departments` -> `Department`). This is a best-effort approach and may not handle all irregular plurals.
- List element typing examines all items in a list to infer the best element type (e.g., `[1, 2.5]` -> `double`, mixed primitives -> `dynamic`). Lists of objects are merged into a single generated class representing the union of their fields.
- Generated fields are nullable by default. If you want `required` semantics, consider post-processing the output or updating the generator rules.
- The Freezed v3 migration has additional semantics (sealed classes, pattern matching changes). Currently the generator changes the class keyword and `.g.dart` usage; further v3-specific adjustments can be added on request.

Contributing

Feel free to open a PR or issue. Small improvements I can help with:
- Better pluralization (irregular nouns map).
- Per-node JSON folding in the editor (tree view with expand/collapse).
- Support for optional/required field inference.

License

This project is provided as-is.
