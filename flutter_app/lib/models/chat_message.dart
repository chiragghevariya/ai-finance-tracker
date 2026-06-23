/// One message in the AI chat.
class ChatMessage {
  final String text;

  /// true  = sent by the user (shown on the right),
  /// false = the AI assistant (shown on the left).
  final bool isUser;

  /// true if this is an error message (shown in a red-tinted bubble).
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });
}
