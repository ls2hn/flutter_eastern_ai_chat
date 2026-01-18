import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';

import '../data/chat.dart';
import '../data/chat_repository.dart';
import '../data/http_llm_provider.dart';
import '../login_info.dart';
import 'chat_list_view.dart';
import 'split_or_tabs.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  LlmProvider? _provider;
  ChatRepository? _repository;
  String? _currentChatId;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_setRepository());
    _setProvider();
  }

  Future<void> _setRepository() async {
    assert(_repository == null);
    try {
      _repository = await ChatRepository.forCurrentUser;
      if (_repository!.chats.isEmpty) {
        await _repository!.addChat();
      }
      await _setChat(_repository!.chats.last);
    } catch (e) {
      debugPrint('Error setting repository: $e');
      _error = e.toString();
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _setChat(Chat chat) async {
    assert(_currentChatId != chat.id);
    _currentChatId = chat.id;
    final history = await _repository!.getHistory(chat);
    _setProvider(history);
    setState(() {});
  }

  void _setProvider([Iterable<ChatMessage>? history]) {
    _provider?.removeListener(_onHistoryChanged);
    setState(() => _provider = _createProvider(history));
    _provider!.addListener(_onHistoryChanged);
  }

  LlmProvider _createProvider(Iterable<ChatMessage>? history) => HttpLlmProvider(
    history: history,
    apiUrl: 'https://rag-backend-28269840215.asia-northeast3.run.app/v1/chat', // Replace with your actual Cloud Run URL
  );

  Chat? get _currentChat => _repository?.chats.singleWhere((chat) => chat.id == _currentChatId);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('溫古(On-Go)'),
      actions: [
        IconButton(
          onPressed: _repository == null ? null : _onAdd,
          tooltip: 'New Chat',
          icon: const Icon(Icons.edit_square),
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Logout: ${LoginInfo.instance.displayName!}',
          onPressed: () async => LoginInfo.instance.logout(),
        ),
      ],
    ),
    body: _repository == null
        ? Center(child: _error != null ? Text('Error: $_error') : const CircularProgressIndicator())
        : SplitOrTabs(
            tabs: [
              const Tab(text: 'Chats'),
              Tab(text: _currentChat?.title),
            ],
            children: [
              ChatListView(
                chats: _repository!.chats,
                selectedChatId: _currentChatId!,
                onChatSelected: _onChatSelected,
                onRenameChat: _onRenameChat,
                onDeleteChat: _onDeleteChat,
              ),
              LlmChatView(provider: _provider!),
            ],
          ),
  );

  Future<void> _onAdd() async {
    final chat = await _repository!.addChat();
    await _onChatSelected(chat);
  }

  Future<void> _onChatSelected(Chat chat) async {
    if (_currentChatId == chat.id) return;
    await _setChat(chat);
  }

  Future<void> _onHistoryChanged() async {
    final history = _provider!.history.toList();

    // update the history in the database
    await _repository!.updateHistory(_currentChat!, history);

    // if the history is not the first prompt or the user has manually set a
    // chat title is not the default, do nothing more
    if (history.length != 2) return;
    if (_currentChat!.title != ChatRepository.newChatTitle) return;

    // grab a default chat title for the first prompt
    assert(history[0].origin.isUser);
    assert(history[1].origin.isLlm);
    final provider = _createProvider(history);
    // 원본
    // final stream = provider.sendMessageStream(
    //   'Please give me a short title for this chat. It should be a single, '
    //   'short phrase with no markdown',
    // );
    final stream = provider.sendMessageStream(
      'Please give me a short Korean title for this chat, specifically about user question. It should be a single, '
      'short phrase with no markdown',
    );

    // update the chat title in the database
    final title = await stream.join();
    final chatWithNewTitle = Chat(id: _currentChatId!, title: title.trim());
    await _repository!.updateChat(chatWithNewTitle);
    setState(() => _currentChatId = chatWithNewTitle.id);
  }

  Future<void> _onRenameChat(Chat chat) async {
    final controller = TextEditingController(text: chat.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rename Chat: ${chat.title}'),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Rename')),
        ],
      ),
    );

    if (newTitle != null) {
      await _repository!.updateChat(Chat(id: chat.id, title: newTitle));
      setState(() {});
    }
  }

  Future<void> _onDeleteChat(Chat chat) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Chat: ${chat.title}'),
        content: const Text('이 대화를 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('삭제하기')),
        ],
      ),
    );

    if (shouldDelete ?? false) {
      await _repository!.deleteChat(chat);
      if (_currentChatId == chat.id) await _setChat(_repository!.chats.last);
      setState(() {});
    }
  }
}