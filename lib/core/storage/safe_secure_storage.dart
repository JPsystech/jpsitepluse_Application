import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Resilient wrapper around [FlutterSecureStorage] that handles iOS Keychain
/// edge cases after device reset, backup restore, or app reinstall (such as
/// `OSStatus -25299` `errSecDuplicateItem`, accessibility level mismatches,
/// or corrupted keychain items).
class SafeSecureStorage {
  SafeSecureStorage._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const List<KeychainAccessibility> _iosAccessibilityLevels = [
    KeychainAccessibility.unlocked,
    KeychainAccessibility.first_unlock,
    KeychainAccessibility.unlocked_this_device,
    KeychainAccessibility.first_unlock_this_device,
    KeychainAccessibility.passcode,
  ];

  /// Reads [key] from secure storage, falling back across iOS accessibility
  /// levels if needed and returning `null` instead of throwing on keychain errors.
  static Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
  }) async {
    try {
      final val = await _storage.read(
        key: key,
        iOptions: iOptions,
        aOptions: aOptions,
      );
      if (val != null) return val;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SafeSecureStorage] Primary read failed for "$key": $e');
      }
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      for (final level in _iosAccessibilityLevels) {
        try {
          final val = await _storage.read(
            key: key,
            iOptions: IOSOptions(accessibility: level),
          );
          if (val != null) return val;
        } catch (_) {}
      }
    }

    return null;
  }

  /// Writes [value] for [key] to secure storage.
  /// If iOS Keychain throws `errSecDuplicateItem` (-25299) or another update
  /// error, deletes existing entries across all accessibility levels and retries.
  /// Returns `true` if the value was written to secure storage, `false` otherwise.
  static Future<bool> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
  }) async {
    if (value == null) {
      await delete(key: key, iOptions: iOptions, aOptions: aOptions);
      return true;
    }

    try {
      await _storage.write(
        key: key,
        value: value,
        iOptions: iOptions,
        aOptions: aOptions,
      );
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[SafeSecureStorage] Primary write failed for "$key" ($e); deleting and retrying...',
        );
      }
      await delete(key: key, iOptions: iOptions, aOptions: aOptions);
      try {
        await _storage.write(
          key: key,
          value: value,
          iOptions: iOptions,
          aOptions: aOptions,
        );
        return true;
      } catch (retryError) {
        if (kDebugMode) {
          debugPrint(
            '[SafeSecureStorage] Retry write failed for "$key": $retryError',
          );
        }
        return false;
      }
    }
  }

  /// Deletes [key] from secure storage across all iOS accessibility permutations,
  /// swallowing any platform keychain errors so callers never crash.
  static Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
  }) async {
    try {
      await _storage.delete(
        key: key,
        iOptions: iOptions,
        aOptions: aOptions,
      );
    } catch (_) {}

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      for (final level in _iosAccessibilityLevels) {
        for (final sync in const [false, true]) {
          try {
            await _storage.delete(
              key: key,
              iOptions: IOSOptions(
                accessibility: level,
                synchronizable: sync,
              ),
            );
          } catch (_) {}
        }
      }
    }
  }
}
