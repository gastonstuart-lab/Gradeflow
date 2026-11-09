import 'dart:js_interop';

// The in-memory browser value is written in web/index.html before bootstrap.
@JS('__gradeflowEntryPath')
external JSString? get _gradeflowEntryPath;

String? capturedBrowserEntryPath() => _gradeflowEntryPath?.toDart;
