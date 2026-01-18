import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:http/http.dart' as http;

class HttpLlmProvider extends ChangeNotifier implements LlmProvider {
  HttpLlmProvider({
    required this.apiUrl,
    Iterable<ChatMessage>? history,
  }) : _history = List<ChatMessage>.from(history ?? const []);

  final String apiUrl;

  List<ChatMessage> _history;

  @override
  Iterable<ChatMessage> get history => _history;

  @override
  set history(Iterable<ChatMessage> value) {
    _history = List<ChatMessage>.from(value);
    notifyListeners();
  }

  ChatMessage _userMessage(String text, {String? messageId}) {
    return ChatMessage.fromJson({
      'origin': 'user',
      'text': text,
      'attachments': [],
      if (messageId != null) 'messageId': messageId,
      'status': 'final',
    });
  }

  ChatMessage _llmMessage(String text, {required String messageId, required String status}) {
    return ChatMessage.fromJson({
      'origin': 'llm',
      'text': text,
      'attachments': [],
      'messageId': messageId,
      'status': status, // 'streaming' | 'final' | 'error'
    });
  }

  @override
  Stream<String> generateStream(
    String message, {
    Iterable<Attachment>? attachments,
  }) async* {
    final client = http.Client();

    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      client.close();
      return;
    }

    // backend 전송용 스냅샷
    final priorHistory = List<ChatMessage>.from(_history);

    // turn 단위 id (user/assistant를 같은 turnId로 묶고 싶으면 이걸 turnId로 써도 됨)
    final turnId = DateTime.now().microsecondsSinceEpoch.toString();
    final assistantMessageId = '${turnId}_a';

    // UI 즉시 반영: user + 빈 assistant 버블(스트리밍용)
    _history.add(_userMessage(message, messageId: '${turnId}_u'));
    _history.add(_llmMessage('', messageId: assistantMessageId, status: 'streaming'));
    notifyListeners();

    final assistantIndex = _history.length - 1;
    final assistantBuffer = StringBuffer();

    try {
      final messages = priorHistory
          .where((m) => ((m.text ?? '').trim().isNotEmpty))
          .map((m) => {
                'role': m.origin.isUser ? 'user' : 'assistant',
                'content': (m.text ?? ''),
              })
          .toList();

      messages.add({'role': 'user', 'content': message});

      final request = http.Request('POST', Uri.parse(apiUrl));
      request.headers['Content-Type'] = 'application/json';

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final token = await user.getIdToken(false).timeout(const Duration(seconds: 8));
          request.headers['Authorization'] = 'Bearer $token';
        } catch (e, st) {
          debugPrint('getIdToken error: $e\n$st');
          debugPrintStack(stackTrace: st);
        }
      }

      request.body = jsonEncode({'messages': messages});
      final response = await client.send(request);

      if (response.statusCode != 200) {
        final errText = 'Error: ${response.statusCode}';
        _history[assistantIndex] =
            _llmMessage(errText, messageId: assistantMessageId, status: 'error');
        notifyListeners();
        yield errText;
        return;
      }

      // 스트리밍: chunk마다 history의 assistant 텍스트를 갱신 -> UI 스트리밍 살아남
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        assistantBuffer.write(chunk);
        _history[assistantIndex] = _llmMessage(
          assistantBuffer.toString(),
          messageId: assistantMessageId,
          status: 'streaming',
        );
        notifyListeners();
        yield chunk;
      }

      final finalText = assistantBuffer.toString();

      if (finalText.trim().isEmpty) {
        // 아무것도 안 왔다면 placeholder 제거
        _history.removeAt(assistantIndex);
        notifyListeners();
        return;
      }

      // 최종 확정 상태로 바꿔줌 (Firestore는 이 상태를 보고 최종 저장/업데이트)
      _history[assistantIndex] =
          _llmMessage(finalText, messageId: assistantMessageId, status: 'final');
      notifyListeners();
    } catch (e, st) {
      debugPrint('HTTP streaming error: $e\n$st');
      debugPrintStack(stackTrace: st);

      final errText = 'Error: $e';
      _history[assistantIndex] =
          _llmMessage(errText, messageId: assistantMessageId, status: 'error');
      notifyListeners();
      yield errText;
    } finally {
      client.close();
    }
  }

  @override
  Stream<String> sendMessageStream(String message, {Iterable<Attachment>? attachments}) =>
      generateStream(message, attachments: attachments);
}
