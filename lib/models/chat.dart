/// Represents the role in a chat turn
enum ChatRole { user, assistant }

/// Represents an agentic action proposed by the assistant for user confirmation
class AssistantAction {
  final String name;
  final Map<String, dynamic> args;

  const AssistantAction({
    required this.name,
    required this.args,
  });

  factory AssistantAction.fromJson(Map<String, dynamic> json) {
    return AssistantAction(
      name: (json['name'] as String?) ?? '',
      args: (json['args'] as Map<String, dynamic>?) ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'args': args,
      };

  @override
  String toString() => 'AssistantAction(name: $name, args: $args)';
}

/// Represents a compact structured promo suggestion for shoppers
class SuggestedPromo {
  final String id;
  final String title;
  final String businessName;
  final String value;
  final String? distance;

  const SuggestedPromo({
    required this.id,
    required this.title,
    required this.businessName,
    required this.value,
    this.distance,
  });

  factory SuggestedPromo.fromJson(Map<String, dynamic> json) {
    return SuggestedPromo(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      businessName: (json['business_name'] as String?) ??
          (json['businessName'] as String?) ??
          '',
      value: (json['value'] as String?) ??
          (json['value_label'] as String?) ??
          '',
      distance: json['distance'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'business_name': businessName,
        'value': value,
        if (distance != null) 'distance': distance,
      };

  @override
  String toString() =>
      'SuggestedPromo(id: $id, title: $title, business: $businessName, value: $value, distance: $distance)';
}

/// Represents a segment of a message, either plain text or a drafted block
class MessageSegment {
  final String text;
  final bool isDraft;

  const MessageSegment({
    required this.text,
    this.isDraft = false,
  });
}

/// Strips markdown emphasis characters (*, _, `) from text
String _stripEmphasis(String text) {
  return text
      .replaceAll('**', '')
      .replaceAll('__', '')
      .replaceAll('*', '')
      .replaceAll('_', '')
      .replaceAll('`', '');
}

/// Sanitizes plain text outside :::draft blocks
String _sanitizeTextOutsideDraft(String text) {
  final uuidRegex = RegExp(
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
  );
  final fnCallRegex = RegExp(
    r'^\s*(call:\s*)?[a-zA-Z_]\w*\s*\([^)]*=.*?\)\s*$',
    caseSensitive: false,
  );
  final proposeActionsRegex = RegExp(
    r'^\s*(#+\s*)?(\*\*)?proposed?\s+actions?:?(\*\*)?',
    caseSensitive: false,
  );
  final bulletRegex = RegExp(r'^(\s*)[*\-]\s+');

  final rawLines = text.split(RegExp(r'\r?\n'));
  final filteredLines = <String>[];

  for (var line in rawLines) {
    // Strip leading # headings
    line = line.replaceFirst(RegExp(r'^#+\s*'), '');

    // Remove line if starts with "Propose Actions"
    if (proposeActionsRegex.hasMatch(line)) {
      continue;
    }

    // Remove line if looks like a function call
    if (fnCallRegex.hasMatch(line)) {
      continue;
    }

    // Turn leading "* " or "- " into "• "
    line = line.replaceFirstMapped(bulletRegex, (m) => '${m[1]}• ');

    // Strip emphasis characters (*, _, `) from line
    line = _stripEmphasis(line);

    // Strip UUIDs
    line = line.replaceAll(uuidRegex, '');

    // Trim trailing spaces
    line = line.trimRight();

    filteredLines.add(line);
  }

  var joined = filteredLines.join('\n');

  // Collapse more than two blank lines
  joined = joined.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  return joined.trim();
}

/// Client-side sanitizer applied to assistant replies before display:
/// - Strips markdown characters (**, __, `, leading #)
/// - Strips UUIDs
/// - Removes lines that look like function calls or start with "Propose Actions"
/// - Turns leading "* " or "- " into "• "
/// - Trims trailing spaces on lines
/// - Collapses more than two blank lines
/// - Protects text inside :::draft blocks except removing markdown emphasis characters
String sanitizeAssistantReply(String content) {
  if (content.isEmpty) return content;

  final draftRegex = RegExp(r':::draft\s*([\s\S]*?)\s*:::', multiLine: true);
  final matches = draftRegex.allMatches(content).toList();

  if (matches.isEmpty) {
    return _sanitizeTextOutsideDraft(content);
  }

  final buffer = StringBuffer();
  int lastIndex = 0;

  for (final match in matches) {
    if (match.start > lastIndex) {
      final outsideText = content.substring(lastIndex, match.start);
      final cleanedOutside = _sanitizeTextOutsideDraft(outsideText);
      if (cleanedOutside.isNotEmpty) {
        if (buffer.isNotEmpty) {
          buffer.writeln();
          buffer.writeln();
        }
        buffer.write(cleanedOutside);
      }
    }

    final insideDraft = match.group(1) ?? '';
    // Do not touch text inside :::draft blocks except removing markdown emphasis characters
    final cleanedDraft = _stripEmphasis(insideDraft).trim();
    if (buffer.isNotEmpty) {
      buffer.writeln();
      buffer.writeln();
    }
    buffer.write(':::draft\n$cleanedDraft\n:::');

    lastIndex = match.end;
  }

  if (lastIndex < content.length) {
    final remaining = content.substring(lastIndex);
    final cleanedRemaining = _sanitizeTextOutsideDraft(remaining);
    if (cleanedRemaining.isNotEmpty) {
      if (buffer.isNotEmpty) {
        buffer.writeln();
        buffer.writeln();
      }
      buffer.write(cleanedRemaining);
    }
  }

  return buffer.toString().trim();
}

/// Parses text containing :::draft ... ::: blocks into structured segments
List<MessageSegment> parseDraftBlocks(String content) {
  final segments = <MessageSegment>[];
  final regex = RegExp(r':::draft\s*([\s\S]*?)\s*:::', multiLine: true);
  int lastIndex = 0;

  for (final match in regex.allMatches(content)) {
    if (match.start > lastIndex) {
      final before = content.substring(lastIndex, match.start).trim();
      if (before.isNotEmpty) {
        segments.add(MessageSegment(text: before, isDraft: false));
      }
    }

    final draftText = match.group(1)?.trim() ?? '';
    if (draftText.isNotEmpty) {
      segments.add(MessageSegment(text: draftText, isDraft: true));
    }

    lastIndex = match.end;
  }

  if (lastIndex < content.length) {
    final remaining = content.substring(lastIndex).trim();
    if (remaining.isNotEmpty) {
      segments.add(MessageSegment(text: remaining, isDraft: false));
    }
  }

  if (segments.isEmpty && content.trim().isNotEmpty) {
    segments.add(MessageSegment(text: content.trim(), isDraft: false));
  }

  return segments;
}

/// Represents a single message bubble in the AI assistant conversation
class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final AssistantAction? action;
  final List<SuggestedPromo> suggestedPromos;
  final bool isError;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.role,
    required String content,
    this.action,
    this.suggestedPromos = const [],
    this.isError = false,
    required this.timestamp,
  }) : content = (role == ChatRole.assistant && !isError)
            ? sanitizeAssistantReply(content)
            : content;

  bool get isUser => role == ChatRole.user;
  bool get isAssistant => role == ChatRole.assistant;

  List<MessageSegment> get segments => parseDraftBlocks(content);

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? content,
    AssistantAction? action,
    List<SuggestedPromo>? suggestedPromos,
    bool? isError,
    DateTime? timestamp,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      action: action ?? this.action,
      suggestedPromos: suggestedPromos ?? this.suggestedPromos,
      isError: isError ?? this.isError,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role == ChatRole.user ? 'user' : 'model',
        'content': content,
      };
}
