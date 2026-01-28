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

  // LlmChatView에 연결할 messageSender (응답 스트림 동안만 _isThinking=true)
  Stream<String> _messageSender(
    String prompt, {
    required Iterable<Attachment> attachments,
  }) async* {
    if (mounted) setState(() => _isThinking = true);

    try {
      // provider가 null일 수 없는 흐름에서만 호출되도록 되어 있어야 합니다.
      final stream = _provider!.sendMessageStream(prompt, attachments: attachments);

      await for (final chunk in stream) {
        yield chunk;
      }
    } finally {
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
    setState(() {
      _isThinking = false;
      _provider = _createProvider(history);
    });
    _provider!.addListener(_onHistoryChanged);
  }

  LlmProvider _createProvider(Iterable<ChatMessage>? history) => HttpLlmProvider(
        history: history,
        apiUrl: 'https://rag-backend-28269840215.asia-northeast3.run.app/v1/chat',
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
        title: const Text('溫古(On-Go)'),

        // AppBar 기본색 제거(투명) + 재질감(머티리얼3) 틴트 제거
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,

        // 상태바 아이콘(시간/배터리) 밝게
        systemOverlayStyle: SystemUiOverlayStyle.light,

        // 여기서 질감 배경 깔기
        flexibleSpace: Stack(
          fit: StackFit.expand,
          children: [
            // 1) 텍스처 이미지 (타일링 또는 커버)
            Opacity(
              opacity: 0.9, // 질감 세기(원하시는 대로 0.15~0.35 조절)
              child: Image.asset(
                'assets/images/ink.png',
                repeat: ImageRepeat.repeat, // 텍스처면 repeat 추천
                fit: BoxFit.none,           // repeat일 때 보통 none
                filterQuality: FilterQuality.medium,
                alignment: Alignment.topLeft,
              ),
            ),

            // 2) 먹색 베이스 오버레이(텍스트 가독성 유지)
            Container(
              color: const Color(0xFF1F1B16).withOpacity(0.01), // 먹색 느낌 (조절 가능)
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
                    //  한지 배경 (아주 옅게 5~8%)
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: true,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // (선택) 베이스 컬러를 아주 연한 미색으로 깔고 싶으면 사용
                            // Container(color: const Color(0xFFF7F2E8)),

                            // 텍스처 이미지
                            Opacity(
                              opacity: 0.8, // ✅ 5~8% 권장: 0.05~0.08
                              child: Image.asset(
                                'assets/images/hanji.png',
                                // ✅ 타일링 텍스처면 repeat 추천 (정사각형 seamless 텍스처에 최적)
                                repeat: ImageRepeat.repeat,
                                fit: BoxFit.none,

                                // 큰 이미지(스캔본)로 "한 장"처럼 쓰고 싶으면 아래처럼 바꾸세요:
                                // repeat: ImageRepeat.noRepeat,
                                // fit: BoxFit.cover,

                                filterQuality: FilterQuality.medium,
                                alignment: Alignment.topLeft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ✅ 2) 기존 LayoutBuilder + LlmChatView
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 600;

                        final bubbleMaxWidth = isMobile
                            ? (constraints.maxWidth - 16).clamp(0, double.infinity).toDouble()
                            : 600.0;

                        final baseStyle = AppTheme.chatStyle(
                          context,
                          hintText: '고민이 있나요? 궁금한 내용을 말해주세요.',
                        );

                        final newLlmStyle =
                            (baseStyle.llmMessageStyle ?? LlmMessageStyle.defaultStyle()).copyWith(
                          icon: null,
                          maxWidth: bubbleMaxWidth,
                          minWidth: 0,
                          flex: 14,
                        );

                        final newChatStyle = baseStyle.copyWith(
                          llmMessageStyle: newLlmStyle,
                          padding: isMobile ? const EdgeInsets.fromLTRB(8, 8, 8, 12) : baseStyle.padding,

                          // ✅ 중요: LlmChatView 자체 배경을 투명으로 해야
                          // 뒤에 깐 hanji 텍스처가 보입니다.
                          backgroundColor: Colors.transparent,
                        );

                        return LlmChatView(
                          provider: _provider!,
                          style: newChatStyle,
                          messageSender: _messageSender,

                          enableVoiceNotes: false,
                          enableAttachments: false,
                        );
                      },
                    ),

                    // "생각중..." 표시 (기존 그대로)
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
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.6),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
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

    // 1) 히스토리 DB 업데이트
    await repo.updateHistory(chat, history);

    // 2) 이미 제목이 바뀐 채팅이거나, 생성 중이면 종료
    if (_isGeneratingTitle) return;
    if (chat.title != ChatRepository.newChatTitle) return;

    // 3) "첫 user 질문" + "그에 대한 첫 llm 답변"이 생겼을 때만 제목 생성
    final userIdx = history.indexWhere((m) => m.origin.isUser);
    if (userIdx < 0) return;
    final llmIdx = history.indexWhere((m) => m.origin.isLlm, userIdx + 1);
    if (llmIdx < 0) return;

    final firstUser = history[userIdx];
    final firstLlm = history[llmIdx];

    final userText = (firstUser.text ?? '').trim();
    final llmText = (firstLlm.text ?? '').trim();


    // 텍스트도 없고 첨부도 없으면 스킵 (text는 null일 수 있음)
    if (userText.isEmpty && firstUser.attachments.isEmpty) return;
    if (llmText.isEmpty && firstLlm.attachments.isEmpty) return;

    _isGeneratingTitle = true;
    try {
      // 제목 생성에는 첫 Q/A만 넣기
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

/* ===========================
   아래는 "현재 사용 중인" ChatListView UI 그대로
   =========================== */

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

          final cardColor = selected ? brandSecondary.withOpacity(0.14) : Colors.white;
          final borderColor =
              selected ? brandSecondary.withOpacity(0.85) : brandSecondary.withOpacity(0.40);

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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 34,
                      decoration: BoxDecoration(
                        color: selected ? brandSecondary.withOpacity(0.95) : Colors.transparent,
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
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    PopupMenuButton<_ChatAction>(
                      tooltip: '메뉴',
                      icon: Icon(Icons.more_vert, color: brandPrimary.withOpacity(0.85)),
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