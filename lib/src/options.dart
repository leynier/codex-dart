enum ApprovalMode {
  never('never'),
  onRequest('on-request'),
  onFailure('on-failure'),
  untrusted('untrusted');

  const ApprovalMode(this.value);
  final String value;
}

enum SandboxMode {
  readOnly('read-only'),
  workspaceWrite('workspace-write'),
  dangerFullAccess('danger-full-access');

  const SandboxMode(this.value);
  final String value;
}

enum ModelReasoningEffort {
  minimal('minimal'),
  low('low'),
  medium('medium'),
  high('high'),
  xhigh('xhigh');

  const ModelReasoningEffort(this.value);
  final String value;
}

enum WebSearchMode {
  disabled('disabled'),
  cached('cached'),
  live('live');

  const WebSearchMode(this.value);
  final String value;
}

class ThreadOptions {
  const ThreadOptions({
    this.model,
    this.sandboxMode,
    this.workingDirectory,
    this.skipGitRepoCheck,
    this.modelReasoningEffort,
    this.networkAccessEnabled,
    this.webSearchMode,
    this.webSearchEnabled,
    this.approvalPolicy,
    this.additionalDirectories,
  });

  final String? model;
  final SandboxMode? sandboxMode;
  final String? workingDirectory;
  final bool? skipGitRepoCheck;
  final ModelReasoningEffort? modelReasoningEffort;
  final bool? networkAccessEnabled;
  final WebSearchMode? webSearchMode;
  final bool? webSearchEnabled;
  final ApprovalMode? approvalPolicy;
  final List<String>? additionalDirectories;
}

class TurnOptions {
  const TurnOptions({this.outputSchema, this.cancelSignal});

  final Object? outputSchema;
  final Future<void>? cancelSignal;
}

sealed class UserInput {
  const UserInput();

  factory UserInput.text(String text) => TextUserInput(text);

  factory UserInput.localImage(String path) => LocalImageUserInput(path);
}

final class TextUserInput extends UserInput {
  const TextUserInput(this.text);
  final String text;
}

final class LocalImageUserInput extends UserInput {
  const LocalImageUserInput(this.path);
  final String path;
}
