import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../services/api_service.dart';

/// Holds the AI chat conversation.
///
/// History lives only in memory (it's cleared when the app restarts), exactly
/// as the spec asks.
class AiChatProvider extends ChangeNotifier {
  final ApiService _api;
  AiChatProvider(this._api);

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  /// Read-only view of the conversation so the UI can't mutate it directly.
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  /// True while we're waiting for the AI's reply (shows a "typing" bubble).
  bool get isLoading => _isLoading;

  /// Send the user's message and append the AI's reply.
  Future<void> send(String text) async {
    final message = text.trim();
    // Ignore empty messages or taps while a reply is already in flight.
    if (message.isEmpty || _isLoading) return;

    // 1. Show the user's message immediately.
    _messages.add(ChatMessage(text: message, isUser: true));
    _isLoading = true;
    notifyListeners();

    // 2. Ask the backend, then show the reply (or an error bubble).
    try {
      final reply = await _api.chat(message);
      _messages.add(ChatMessage(text: reply, isUser: false));
    } on ApiException catch (e) {
      // e.g. 503 when the backend's OPENAI_API_KEY isn't set.
      _messages.add(ChatMessage(text: e.message, isUser: false, isError: true));
    } catch (_) {
      _messages.add(ChatMessage(
        text: 'Something went wrong. Please try again.',
        isUser: false,
        isError: true,
      ));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear the whole conversation.
  void clear() {
    _messages.clear();
    notifyListeners();
  }
}
