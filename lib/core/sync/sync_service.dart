class SyncResult {
  const SyncResult({required this.pushed, required this.failed});

  final int pushed;
  final int failed;

  bool get hasFailures => failed > 0;
  String get summary => '$pushed pushed, $failed failed';
}

abstract class SyncService {
  Future<SyncResult> pushPendingChanges();

  Future<SyncResult> pullRemoteChanges();
}
