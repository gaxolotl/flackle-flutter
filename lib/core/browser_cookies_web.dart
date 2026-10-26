/// Reads first-party cookies on Flutter web. Credentials are HttpOnly in most
/// cases; the readable ones (such as the CSRF token) are what the API needs in
/// the `X-CSRF-Token` header.
library;

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Map<String, String> readBrowserCookies() {
  final cookies = <String, String>{};
  final raw = html.document.cookie ?? '';
  if (raw.isEmpty) return cookies;
  for (final part in raw.split(';')) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) continue;
    final separator = trimmed.indexOf('=');
    if (separator <= 0) continue;
    cookies[trimmed.substring(0, separator)] =
        Uri.decodeComponent(trimmed.substring(separator + 1));
  }
  return cookies;
}
