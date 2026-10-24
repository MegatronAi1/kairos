import 'package:kairos_pager/core/models/models.dart';

/// One message of an Ask Kairos conversation.
class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    this.evidence = const [],
    this.error = false,
  });

  final String role; // 'user' | 'assistant'
  final String content;
  final List<String> evidence;
  final bool error;

  bool get isUser => role == 'user';

  Json toJson() => {'role': role, 'content': content};

  ChatMessage copyWith({String? content, List<String>? evidence, bool? error}) => ChatMessage(
    role: role,
    content: content ?? this.content,
    evidence: evidence ?? this.evidence,
    error: error ?? this.error,
  );
}

/// Server-sent event from `POST /agent/chat`.
sealed class ChatEvent {
  const ChatEvent();

  /// Parses one `data:` payload; unknown types return null.
  static ChatEvent? fromJson(Json j) => switch (j['type']) {
    'text' => ChatText(j['delta'] as String? ?? ''),
    'tool' => ChatTool(j['name'] as String? ?? ''),
    'evidence' => ChatEvidence(((j['items'] as List?) ?? const []).map((e) => '$e').toList()),
    'done' => const ChatDone(),
    'error' => ChatError(j['message'] as String? ?? 'Kairos could not answer.'),
    _ => null,
  };
}

class ChatText extends ChatEvent {
  const ChatText(this.delta);
  final String delta;
}

class ChatTool extends ChatEvent {
  const ChatTool(this.name);
  final String name;

  /// "recommend_settings" -> "recommend settings".
  String get label => name.replaceAll('_', ' ');
}

class ChatEvidence extends ChatEvent {
  const ChatEvidence(this.items);
  final List<String> items;
}

class ChatDone extends ChatEvent {
  const ChatDone();
}

class ChatError extends ChatEvent {
  const ChatError(this.message);
  final String message;
}
