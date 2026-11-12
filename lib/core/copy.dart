import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'api.dart';

class Copy {
  static final Map<String, Copy> _cache = {};
  static Future<void> preload() async {
    for (final locale in ['en', 'km']) {
      _cache[locale] = Copy(
        (jsonDecode(
                  await rootBundle.loadString(
                    'assets/i18n/$locale.json',
                    cache: false,
                  ),
                )
                as Map)
            .cast<String, String>(),
      );
    }
  }

  final Map<String, String> values;
  const Copy(this.values);
  String t(String key) => values[key] ?? key;
  static Copy of(BuildContext context) =>
      Localizations.of<Copy>(context, Copy)!;
  static const delegate = _CopyDelegate();
  String error(Object error) {
    if (error is ApiFailure) {
      if (error.status == 403) return t('forbidden');
      if (error.status == 404) return t('notFound');
      if (error.status == 401) return t('sessionExpired');
      if (error.errors.isNotEmpty) {
        return error.errors.entries
            .map(
              (e) =>
                  '${e.value is List ? (e.value as List).join('\n') : e.value}',
            )
            .join('\n');
      }
      return values[error.message] ?? error.message;
    }
    return t('unexpected');
  }
}

class _CopyDelegate extends LocalizationsDelegate<Copy> {
  const _CopyDelegate();
  @override
  bool isSupported(Locale locale) => ['en', 'km'].contains(locale.languageCode);
  @override
  Future<Copy> load(Locale locale) =>
      Copy._cache.containsKey(locale.languageCode)
      ? SynchronousFuture(Copy._cache[locale.languageCode]!)
      : rootBundle
            .loadString('assets/i18n/${locale.languageCode}.json', cache: false)
            .then(
              (value) =>
                  Copy((jsonDecode(value) as Map).cast<String, String>()),
            );
  @override
  bool shouldReload(_CopyDelegate old) => false;
}

extension CopyContext on BuildContext {
  String t(String key) => Copy.of(this).t(key);
}
