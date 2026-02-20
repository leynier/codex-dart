class CodexException implements Exception {
  CodexException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() {
    if (cause == null) {
      return message;
    }
    return '$message (cause: $cause)';
  }
}

class CodexExecutableNotFoundException extends CodexException {
  CodexExecutableNotFoundException(super.message);
}

class CodexExecException extends CodexException {
  CodexExecException(super.message, {super.cause});
}

class CodexParseException extends CodexException {
  CodexParseException(super.message, {super.cause});
}

class CodexCanceledException extends CodexException {
  CodexCanceledException(super.message);
}

class ThreadRunException extends CodexException {
  ThreadRunException(super.message);
}
