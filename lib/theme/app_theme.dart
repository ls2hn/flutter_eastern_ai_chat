import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'brand_colors.dart';

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandPrimary,
      brightness: Brightness.light,
    ).copyWith(
      primary: brandPrimary,
      secondary: brandSecondary,
      background: backgroundTone,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: backgroundTone,

      appBarTheme: const AppBarTheme(
        backgroundColor: brandPrimary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: brandSecondary.withOpacity(0.55)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: brandSecondary.withOpacity(0.55)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: brandPrimary, width: 1.4),
        ),
      ),
    );
  }

  /// Flutter AI Toolkit 채팅 UI 스타일
  static LlmChatViewStyle chatStyle(BuildContext context) {
    return LlmChatViewStyle(
      backgroundColor: backgroundTone,
      menuColor: Colors.white,
      progressIndicatorColor: brandPrimary,

      // 사용자 말풍선(오른쪽)
      userMessageStyle: UserMessageStyle(
        textStyle: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: Colors.white, height: 1.35),
        decoration: const BoxDecoration(
          color: brandPrimary,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(6),
          ),
        ),
      ),

      // AI 말풍선(왼쪽)
      llmMessageStyle: LlmMessageStyle(
        icon: Icons.auto_awesome,
        iconColor: brandPrimary,
        iconDecoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: brandSecondary.withOpacity(0.55)),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(6),
          ),
          border: Border.all(color: brandSecondary.withOpacity(0.45)),
        ),
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 5),
      ),

      // 입력창
      chatInputStyle: ChatInputStyle(
        hintText: '메시지를 입력하세요',
        // ChatInputStyle은 문서상 textStyle/hintText 등 지원 :contentReference[oaicite:1]{index=1}
        textStyle: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: brandPrimary),
        hintStyle: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: brandPrimary.withOpacity(0.45)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: brandSecondary.withOpacity(0.55)),
        ),
      ),

      // 버튼 톤 통일 (submit/attach/camera/record 등은 LlmChatViewStyle로 스타일 지정 가능) :contentReference[oaicite:2]{index=2}
      submitButtonStyle: ActionButtonStyle(
        iconColor: Colors.white,
        iconDecoration: BoxDecoration(
          color: brandPrimary,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      attachFileButtonStyle: ActionButtonStyle(
        iconColor: brandPrimary,
        iconDecoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: brandSecondary.withOpacity(0.6)),
        ),
      ),
      cameraButtonStyle: ActionButtonStyle(
        iconColor: brandPrimary,
        iconDecoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: brandSecondary.withOpacity(0.6)),
        ),
      ),
      recordButtonStyle: ActionButtonStyle(
        iconColor: brandPrimary,
        iconDecoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: brandSecondary.withOpacity(0.6)),
        ),
      ),

      suggestionStyle: SuggestionStyle(
        textStyle: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: brandPrimary),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: brandSecondary.withOpacity(0.55)),
        ),
      ),
    );
  }
}