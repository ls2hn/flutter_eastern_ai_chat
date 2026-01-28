import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:flutter/services.dart';

import '../data/chat.dart';
import '../data/chat_repository.dart';
import '../data/http_llm_provider.dart';
import '../login_info.dart';
import '../theme/app_theme.dart';
import '../theme/brand_colors.dart';
import 'split_or_tabs.dart';

import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  LlmProvider? _provider;
  ChatRepository? _repository;
  String? _currentChatId;
  String? _error;

  bool _isGeneratingTitle = false;
  // "생각중..." 표시용 상태
  bool _isThinking = false;

  // ✅ 새 채팅(히스토리 없음)일 때만 캐릭터 오버레이 표시
  bool _showEmptyCharacter = false;

  bool _isChatEmpty(Iterable<ChatMessage>? history) {
    if (history == null) return true;
    // system 메시지 등이 섞일 수 있어서 user/llm 메시지 유무로 판단
    return !history.any((m) => m.origin.isUser || m.origin.isLlm);
  }

  // LlmChatView에 연결할 messageSender (응답 스트림 동안만 _isThinking=true)
  Stream<String> _messageSender(
    String prompt, {
    required Iterable<Attachment> attachments,
  }) async* {
    if (mounted) {
      setState(() {
        _isThinking = true;
        //_showEmptyCharacter = false; // 질문 보내는 즉시 캐릭터 숨김(원하시면)
      });
    }

    bool firstTokenArrived = false;

    try {
      final stream = _provider!.sendMessageStream(prompt, attachments: attachments);

      await for (final chunk in stream) {
        // "첫 토큰(의미 있는 텍스트)" 도착 순간에 생각중... 끄기
        if (!firstTokenArrived && chunk.trim().isNotEmpty) {
          firstTokenArrived = true;
          if (mounted) setState(() => _isThinking = false);
        }

        yield chunk;
      }
    } finally {
      // 스트림이 에러/종료되면 안전하게 끄기
      if (mounted) setState(() => _isThinking = false);
    }
  }

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
    if (_currentChatId == chat.id) return;
    _currentChatId = chat.id;
    final history = await _repository!.getHistory(chat);
    _setProvider(history);
    if (mounted) setState(() {});
  }

  void _setProvider([Iterable<ChatMessage>? history]) {
    _provider?.removeListener(_onHistoryChanged);

    // ignore: unused_local_variable
    final shouldShow = _isChatEmpty(history);

    setState(() {
      _isThinking = false;
      _showEmptyCharacter = true; // 비어있으면 캐릭터 보이기
      _provider = _createProvider(history);
    });

    _provider!.addListener(_onHistoryChanged);
  }

  LlmProvider _createProvider(Iterable<ChatMessage>? history) => HttpLlmProvider(
        history: history,
        apiUrl:
            'https://rag-backend-28269840215.asia-northeast3.run.app/v1/chat',
      );

  Chat? get _currentChat {
    final repo = _repository;
    final id = _currentChatId;
    if (repo == null || id == null) return null;
    try {
      return repo.chats.singleWhere((chat) => chat.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('溫故(On-Go)'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          shadowColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          flexibleSpace: Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: 0.86,
                child: Image.asset(
                  'assets/images/ink.png',
                  repeat: ImageRepeat.repeat,
                  fit: BoxFit.none,
                  filterQuality: FilterQuality.medium,
                  alignment: Alignment.topLeft,
                ),
              ),
              Container(
                color: const Color(0xFF1F1B16).withOpacity(0.01),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _repository == null ? null : _onAdd,
              tooltip: '새 대화',
              icon: const Icon(Icons.edit_square),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: '로그아웃: ${LoginInfo.instance.displayName!}',
              onPressed: () async => LoginInfo.instance.logout(),
            ),
          ],
        ),
        body: _repository == null
            ? Center(
                child: _error != null
                    ? Text('Error: $_error')
                    : const CircularProgressIndicator(),
              )
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
                  Stack(
                    children: [
                      // 한지 배경
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: true,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Opacity(
                                opacity: 0.8,
                                child: Image.asset(
                                  'assets/images/hanji.png',
                                  repeat: ImageRepeat.repeat,
                                  fit: BoxFit.none,
                                  filterQuality: FilterQuality.medium,
                                  alignment: Alignment.topLeft,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // 캐릭터 오버레이
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: true,
                          child: AnimatedOpacity(
                            opacity: _showEmptyCharacter ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 180),
                            child: AnimatedPadding(
                              duration: const Duration(milliseconds: 180),
                              padding: EdgeInsets.only(
                                bottom: 110 +
                                    MediaQuery.of(context).viewInsets.bottom,
                              ),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  widthFactor: 0.55,
                                  child: Opacity(
                                    opacity: 0.95,
                                    child: Image.asset(
                                      'assets/images/character.png',
                                      fit: BoxFit.contain,
                                      filterQuality: FilterQuality.high,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // 채팅 뷰
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isMobile = constraints.maxWidth < 600;
                          final bubbleMaxWidth = isMobile
                              ? (constraints.maxWidth - 16)
                                  .clamp(0, double.infinity)
                                  .toDouble()
                              : 600.0;

                          final baseStyle = AppTheme.chatStyle(
                            context,
                            hintText: '고민이나 궁금한 내용을 말해주세요.',
                          );

                          // 기존 llm 스타일(패딩/마크다운 스타일)을 백업
                          final llmBase = baseStyle.llmMessageStyle ?? LlmMessageStyle.defaultStyle();
                          final llmInnerPadding = llmBase.padding;
                          final llmMarkdownStyle = llmBase.markdownStyle;
                          final llmOuterMargin = llmBase.margin;
                          final llmDecoration = llmBase.decoration;


                          // 말풍선 자체 패딩을 0으로 (빈 응답일 때 말풍선이 0 크기)
                          final newLlmStyle = llmBase.copyWith(
                          icon: null,
                          maxWidth: bubbleMaxWidth,
                          minWidth: 0,
                          flex: 14,
                          padding: EdgeInsets.zero,
                          margin: EdgeInsets.zero,
                          decoration: const BoxDecoration(),
                          );

                          final newChatStyle = baseStyle.copyWith(
                            llmMessageStyle: newLlmStyle,
                            padding: isMobile
                                ? const EdgeInsets.fromLTRB(8, 8, 8, 12)
                                : baseStyle.padding,
                            backgroundColor: Colors.transparent,
                          );

                          return LlmChatView(
                            provider: _provider!,
                            style: newChatStyle,
                            messageSender: _messageSender,

                            // 스트리밍 시작 직후 response == ''이면 아예 렌더링 안 함(테두리도 0)
                            responseBuilder: (context, response) {
                              if (response.trim().isEmpty) {
                                return const SizedBox.shrink(); // <- 이게 “빈 말풍선 생성”을 막는다.
                              }

                              return Padding(
                                padding: llmOuterMargin,
                                child: Container(
                                  decoration: llmDecoration,
                                  padding: llmInnerPadding,
                                  child: MarkdownBody(
                                    data: response,
                                    styleSheet: llmMarkdownStyle ??
                                        MarkdownStyleSheet.fromTheme(Theme.of(context)),
                                  ),
                                ),
                              );
                            },

                            enableVoiceNotes: false,
                            enableAttachments: false,
                          );
                        },
                      ),
                      // "생각중..." 표시
                      Positioned(
                        left: 34,
                        right: 76,
                        bottom: 83 + MediaQuery.of(context).viewInsets.bottom,
                        child: IgnorePointer(
                          ignoring: true,
                          child: AnimatedOpacity(
                            opacity: _isThinking ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 150),
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant
                                        .withOpacity(0.6),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text('생각중...'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
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
    final repo = _repository;
    final provider = _provider;
    final chat = _currentChat;
    if (repo == null || provider == null || chat == null) return;

    final history = provider.history.toList();
    await repo.updateHistory(chat, history);

    if (_isGeneratingTitle) return;
    if (chat.title != ChatRepository.newChatTitle) return;

    final userIdx = history.indexWhere((m) => m.origin.isUser);
    if (userIdx < 0) return;
    final llmIdx = history.indexWhere((m) => m.origin.isLlm, userIdx + 1);
    if (llmIdx < 0) return;

    final firstUser = history[userIdx];
    final firstLlm = history[llmIdx];

    final userText = (firstUser.text ?? '').trim();
    final llmText = (firstLlm.text ?? '').trim();

    if (userText.isEmpty && firstUser.attachments.isEmpty) return;
    if (llmText.isEmpty && firstLlm.attachments.isEmpty) return;

    _isGeneratingTitle = true;
    try {
      final titleProvider = _createProvider([firstUser, firstLlm]);
      final stream = titleProvider.sendMessageStream(
        '사용자의 질문을 기준으로 이 대화의 제목을 아주 짧은 한국어로 만들어 주세요.\n'
        '- 한 줄\n'
        '- 6~14자 정도의 짧은 구(phrase)\n'
        '- 따옴표/마크다운/이모지 금지\n'
        '- 설명 없이 제목만 출력\n',
      );

      final title = (await stream.join()).trim();
      if (title.isEmpty) return;

      final chatWithNewTitle = Chat(id: chat.id, title: title);
      await repo.updateChat(chatWithNewTitle);

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Auto-title generation failed: $e');
    } finally {
      _isGeneratingTitle = false;
    }
  }

  Future<void> _onRenameChat(Chat chat) async {
    final controller = TextEditingController(text: chat.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rename Chat: ${chat.title}'),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newTitle != null) {
      await _repository!.updateChat(Chat(id: chat.id, title: newTitle));
      if (mounted) setState(() {});
    }
  }

  Future<void> _onDeleteChat(Chat chat) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Chat: ${chat.title}'),
        content: const Text('이 대화를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제하기'),
          ),
        ],
      ),
    );

    if (shouldDelete ?? false) {
      await _repository!.deleteChat(chat);
      if (_currentChatId == chat.id && _repository!.chats.isNotEmpty) {
        await _setChat(_repository!.chats.last);
      }
      if (mounted) setState(() {});
    }
  }
}

class ChatListView extends StatelessWidget {
  const ChatListView({
    required this.chats,
    required this.selectedChatId,
    required this.onChatSelected,
    required this.onRenameChat,
    required this.onDeleteChat,
    super.key,
  });

  final List<Chat> chats;
  final String selectedChatId;
  final void Function(Chat) onChatSelected;
  final void Function(Chat) onRenameChat;
  final void Function(Chat) onDeleteChat;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ColoredBox(
      color: backgroundTone,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        itemCount: chats.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final chat = chats[chats.length - index - 1];
          final selected = chat.id == selectedChatId;
          final title = chat.title.trim().isEmpty ? '새 대화' : chat.title.trim();

          final cardColor =
              selected ? brandSecondary.withOpacity(0.14) : Colors.white;
          final borderColor = selected
              ? brandSecondary.withOpacity(0.85)
              : brandSecondary.withOpacity(0.40);

          return Material(
            color: cardColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: borderColor, width: selected ? 1.2 : 1.0),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onChatSelected(chat),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 34,
                      decoration: BoxDecoration(
                        color: selected
                            ? brandSecondary.withOpacity(0.95)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Tooltip(
                        message: title,
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            color: brandPrimary,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    PopupMenuButton<_ChatAction>(
                      tooltip: '메뉴',
                      icon: Icon(
                        Icons.more_vert,
                        color: brandPrimary.withOpacity(0.85),
                      ),
                      onSelected: (action) {
                        switch (action) {
                          case _ChatAction.rename:
                            onRenameChat(chat);
                            break;
                          case _ChatAction.delete:
                            onDeleteChat(chat);
                            break;
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _ChatAction.rename,
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 10),
                              Text('이름 변경'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: _ChatAction.delete,
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18),
                              SizedBox(width: 10),
                              Text('삭제'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

enum _ChatAction { rename, delete }