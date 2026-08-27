import 'dart:io' show Platform;

/// `android`, `ios`, `macos`, `linux`, `windows`.
String osType() {
  try {
    return Platform.operatingSystem;
  } catch (_) {
    return 'unknown';
  }
}

/// Chaîne brute du système — sur Android, la bannière du noyau. La version d'OS
/// explique une bonne part des refus de permission et des différences de
/// comportement du stock Telephony d'un téléphone à l'autre.
String osVersion() {
  try {
    return Platform.operatingSystemVersion;
  } catch (_) {
    return 'unknown';
  }
}
