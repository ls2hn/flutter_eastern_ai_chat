import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartx/dartx.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:uuid/uuid.dart';

import 'chat.dart';

class ChatRepository extends ChangeNotifier {
  ChatRepository._({
    required CollectionReference collection,
    required List<Chat> chats,
  })  : _chatsCollection = collection,
        _chats = chats;

  static const newChatTitle = 'Untitled';
  static User? _currentUser;
  static ChatRepository? _currentUserRepository;

  static bool get hasCurrentUser => _currentUser != null;
  static Future<ChatRepository> get forCurrentUser async {
    if (_currentUser == null) throw Exception('No user logged in');

    if (_currentUserRepository == null) {
      assert(_currentUser != null);
      final collection = FirebaseFirestore.instance
          .collection('users/${_currentUser!.uid}/chats');

      final chats = await ChatRepository._loadChats(collection);

      _currentUserRepository = ChatRepository._(
        collection: collection,
        chats: chats,
      );

      if (chats.isEmpty) {
        await _currentUserRepository!.addChat();
      }
    }

    return _currentUserRepository!;
  }

  static User? get user => _currentUser;

  static set user(User? user) {
    if (user == null) {
      _currentUser = null;
      _currentUserRepository = null;
      return;
    }

    if (user.uid == _currentUser?.uid) return;

    _currentUser = user;
    _currentUserRepository = null;
  }

  static Future<List<Chat>> _loadChats(CollectionReference collection) async {
    final chats = <Chat>[];
    final querySnapshot = await collection.get();
    for (final doc in querySnapshot.docs) {
      chats.add(Chat.fromJson(doc.data()! as Map<String, dynamic>));
    }

    return chats;
  }

  final CollectionReference _chatsCollection;
  final List<Chat> _chats;

  CollectionReference _historyCollection(Chat chat) =>
      _chatsCollection.doc(chat.id).collection('history');

  List<Chat> get chats => _chats;

  Future<Chat> addChat() async {
    final chat = Chat(
      id: const Uuid().v4(),
      title: newChatTitle,
    );

    _chats.add(chat);
    notifyListeners();
    await _chatsCollection.doc(chat.id).set(chat.toJson());

    return chat;
  }

  Future<void> updateChat(Chat chat) async {
    final i = _chats.indexWhere((m) => m.id == chat.id);
    assert(i >= 0);
    _chats[i] = chat;
    notifyListeners();
    await _chatsCollection.doc(chat.id).update(chat.toJson());
  }

  Future<void> deleteChat(Chat chat) async {
    final removed = _chats.remove(chat);
    assert(removed);

    final querySnapshot = await _historyCollection(chat).get();
    for (final doc in querySnapshot.docs) {
      await doc.reference.delete();
    }

    await _chatsCollection.doc(chat.id).delete();
    notifyListeners();

    if (_chats.isEmpty) await addChat();
  }

  Future<List<ChatMessage>> getHistory(Chat chat) async {
    final querySnapshot = await _historyCollection(chat).get();

    final indexedMessages = <int, ChatMessage>{};
    for (final doc in querySnapshot.docs) {
      final index = int.parse(doc.id);
      final message = ChatMessage.fromJson(doc.data()! as Map<String, dynamic>);
      indexedMessages[index] = message;
    }

    final messages = indexedMessages.entries
        .sortedBy((e) => e.key)
        .map((e) => e.value)
        .toList();
    return messages;
  }

  /// - 기존 메시지는 "없을 때만" 생성
  /// - 마지막 assistant 메시지는 스트리밍 중에도 계속 바뀌므로 "항상 set(merge:true)"로 갱신
  ///
  /// 이렇게 하면 Firestore 기반 UI에서도 스트리밍처럼 점진적으로 보일 수 있음
  Future<void> updateHistory(Chat chat, List<ChatMessage> history) async {
    if (history.isEmpty) return;

    final historyCol = _historyCollection(chat);
    final lastIndex = history.length - 1;

    for (var i = 0; i != history.length; ++i) {
      final id = i.toString().padLeft(3, '0');
      final docRef = historyCol.doc(id);

      final message = history[i];
      final json = message.toJson();

      final isAssistant = !(message.origin.isUser);
      final isLast = i == lastIndex;

      // 마지막 assistant는 스트리밍 중 계속 바뀌므로 무조건 갱신
      // (final/error 포함해서 항상 최신으로 유지)
      if (isLast && isAssistant) {
        await docRef.set(json, SetOptions(merge: true));
        continue;
      }

      // 나머지는 기존처럼 "이미 있으면 스킵" (불필요한 write 비용 절감)
      final snap = await docRef.get();
      if (snap.exists) continue;

      await docRef.set(json);
    }
  }
}
