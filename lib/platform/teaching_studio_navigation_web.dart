import 'package:web/web.dart' as web;

bool openTeachingStudio(Uri uri) {
  // Replace the transit route so browser Back returns to the originating page.
  web.window.location.replace(uri.toString());
  return true;
}
