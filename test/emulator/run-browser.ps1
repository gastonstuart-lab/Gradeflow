# Flutter 3.38 on Windows misclassifies CanvasKit URLs as filesystem paths.
# Run the source tool with a temporary one-line fix, restoring its bytes even
# on failure. No precompiled tool snapshot or repository runtime code is changed.
param([string]$FlutterRoot = (Split-Path (Split-Path (Get-Command flutter).Source)))
$ErrorActionPreference = 'Stop'
$sdkSource = Join-Path $FlutterRoot 'packages/flutter_tools/lib/src/test/flutter_web_platform.dart'
$original = [IO.File]::ReadAllBytes($sdkSource)
try {
    $source = [IO.File]::ReadAllText($sdkSource)
    $source = $source.Replace('final String fullPath = _fileSystem.path.fromUri(request.url);', 'final String fullPath = request.url.path;')
    [IO.File]::WriteAllText($sdkSource, $source)
    & "$FlutterRoot/bin/cache/dart-sdk/bin/dart.exe" "--packages=$FlutterRoot/packages/flutter_tools/.dart_tool/package_config.json" "$FlutterRoot/packages/flutter_tools/bin/flutter_tools.dart" test --platform chrome --no-pub test/firestore_grading_period_emulator_test.dart --reporter expanded
    $result = $LASTEXITCODE
} finally {
    [IO.File]::WriteAllBytes($sdkSource, $original)
}
exit $result
