import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gradeflow/models/communication_models.dart';
import 'package:gradeflow/models/user.dart';
import 'package:gradeflow/repositories/communication_repository.dart';
import 'package:gradeflow/repositories/firestore_communication_repository.dart';
import 'package:gradeflow/repositories/local_communication_repository.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/services/auth_service.dart';

class CommunicationService extends ChangeNotifier {
  User? _user;
  CommunicationRepository? _repository;
  bool _loading = false;
  bool _sending = false;
  String? _error;
  List<CommunicationChannelRecord> _channels = const [];
  String? _selectedChannelId;
  final Map<String, List<CommunicationMessage>> _messagesByChannel = {};

  bool get isLoading => _loading;
  bool get isSending => _sending;
  String? get error => _error;
  List<CommunicationChannelRecord> get channels => _channels;
  List<CommunicationMessage> get selectedMessages => _selectedChannelId == null
      ? const []
      : _messagesByChannel[_selectedChannelId!] ?? const [];
  CommunicationChannelRecord? get selectedChannel {
    final selectedId = _selectedChannelId;
    if (selectedId == null) return null;
    for (final channel in _channels) {
      if (channel.channelId == selectedId) {
        return channel;
      }
    }
    return null;
  }

  List<CommunicationMessage> get adminAlertMessages =>
      _messagesByChannel['admin-alerts'] ?? const [];

  int get channelCount => _channels.length;
  int get totalMessageCount => _messagesByChannel.values
      .fold<int>(0, (sum, messages) => sum + messages.length);

  int get activityCount {
    final now = DateTime.now();
    return _messagesByChannel.values
        .expand((messages) => messages)
        .where((message) => now.difference(message.createdAt).inDays < 1)
        .length;
  }

  void syncAuth(AuthService auth) {
    final nextUser = auth.currentUser;
    final backend = RepositoryFactory.backend;
    final repository = _createRepository(backend);
    final userChanged = _user?.userId != nextUser?.userId;
    final repositoryChanged = _repository.runtimeType != repository.runtimeType;

    if (!userChanged && !repositoryChanged) {
      return;
    }

    _user = nextUser;
    _repository = repository;

    if (nextUser == null) {
      _channels = const [];
      _selectedChannelId = null;
      _messagesByChannel.clear();
      _error = null;
      _loading = false;
      notifyListeners();
      return;
    }

    Future.microtask(load);
  }

  Future<void> load() async {
    final user = _user;
    final repository = _repository;
    if (user == null || repository == null) {
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await repository.ensureDefaultChannels(user: user);
      final channels = await repository.loadChannels(user: user);
      final selectedId = _resolveSelectedChannelId(channels);
      _channels = channels;
      _selectedChannelId = selectedId;
      _messagesByChannel.clear();
      if (selectedId != null) {
        _messagesByChannel[selectedId] = await repository.loadMessages(
          user: user,
          channelId: selectedId,
        );
      }
      if (channels.any((channel) => channel.channelId == 'admin-alerts') &&
          !_messagesByChannel.containsKey('admin-alerts')) {
        _messagesByChannel['admin-alerts'] = await repository.loadMessages(
          user: user,
          channelId: 'admin-alerts',
        );
      }
    } catch (error) {
      _error = error.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> selectChannel(String channelId) async {
    final user = _user;
    final repository = _repository;
    if (user == null || repository == null || _selectedChannelId == channelId) {
      return;
    }

    _selectedChannelId = channelId;
    notifyListeners();

    if (_messagesByChannel.containsKey(channelId)) {
      return;
    }

    try {
      _messagesByChannel[channelId] = await repository.loadMessages(
        user: user,
        channelId: channelId,
      );
      notifyListeners();
    } catch (error) {
      _error = error.toString();
      notifyListeners();
    }
  }

  Future<void> sendMessage(String text) async {
    final user = _user;
    final repository = _repository;
    final channel = selectedChannel;
    if (user == null || repository == null || channel == null) {
      return;
    }

    final trimmed = text.trim();
    if (trimmed.isEmpty || channel.readOnly) {
      return;
    }

    _sending = true;
    _error = null;
    notifyListeners();

    try {
      await repository.sendMessage(
        user: user,
        channel: channel,
        text: trimmed,
      );
      await _refreshChannel(channel.channelId);
    } catch (error) {
      _error = error.toString();
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<void> postAdminAlert(
    String text, {
    CommunicationAlertSeverity severity = CommunicationAlertSeverity.attention,
  }) async {
    final user = _user;
    final repository = _repository;
    if (user == null || repository == null || text.trim().isEmpty) {
      return;
    }

    _sending = true;
    _error = null;
    notifyListeners();

    try {
      await repository.postAdminAlert(
        user: user,
        text: text.trim(),
        severity: severity,
      );
      await _refreshChannel('admin-alerts');
    } catch (error) {
      _error = error.toString();
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  CommunicationRepository _createRepository(RepositoryBackend backend) {
    switch (backend) {
      case RepositoryBackend.firestore:
        return FirestoreCommunicationRepository();
      case RepositoryBackend.local:
        return const LocalCommunicationRepository();
    }
  }

  String? _resolveSelectedChannelId(List<CommunicationChannelRecord> channels) {
    if (channels.isEmpty) {
      return null;
    }
    if (_selectedChannelId != null &&
        channels.any((channel) => channel.channelId == _selectedChannelId)) {
      return _selectedChannelId;
    }
    final allStaffChannel =
        channels.where((channel) => channel.channelId == 'all-staff');
    if (allStaffChannel.isNotEmpty) {
      return allStaffChannel.first.channelId;
    }
    return channels.first.channelId;
  }

  Future<void> _refreshChannel(String channelId) async {
    final user = _user;
    final repository = _repository;
    if (user == null || repository == null) {
      return;
    }

    final channels = await repository.loadChannels(user: user);
    _channels = channels;
    _messagesByChannel[channelId] = await repository.loadMessages(
      user: user,
      channelId: channelId,
    );
    _selectedChannelId ??= _resolveSelectedChannelId(channels);
  }
}
