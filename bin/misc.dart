import 'dart:io';

extension Ext<T> on Iterable<T> {
  T? firstOrNull([bool Function(T e)? predicate]) {
    if (predicate == null) {
      return isEmpty ? null : first;
    } else {
      for (final e in this) {
        if (predicate(e)) {
          return e;
        }
      }
      return null;
    }
  }
}

extension FileExt on File {
  String get name {
    final i = path.lastIndexOf(Platform.pathSeparator);
    return i == -1 ? path : path.substring(i + 1);
  }
}

extension ProcessResultExt on ProcessResult {
  String? get outValue => this.stdout as String?;

  String? get errValue => this.stderr as String?;
}
