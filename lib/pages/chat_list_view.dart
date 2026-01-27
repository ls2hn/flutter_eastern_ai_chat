import 'package:flutter/material.dart';

import '../data/chat.dart';
import '../theme/brand_colors.dart';

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
                    // 선택 표시 라인 (선택일 때만)
                    Container(
                      width: 4,
                      height: 34,
                      decoration: BoxDecoration(
                        color: selected ? brandSecondary.withOpacity(0.95) : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // 제목
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

                    // 액션 메뉴(모바일에서 깔끔)
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