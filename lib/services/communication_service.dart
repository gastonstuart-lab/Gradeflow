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
  CommunicationService(
      {CommunicationRepository Function(RepositoryBackend)? repositoryFactory})
      : _repositoryFactory = repositoryFactory;
  final CommunicationRepository Function(RepositoryBackend)? _repositoryFactory;
  int _epoch = 0;
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _clearWorkspace() {
    _channels = const [];
    _selectedChannelId = null;
    _messagesByChannel.clear();
    _readMarkersByChannel.clear();
    _unreadCountsByChannel.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    super.dispose();
  }

  User? _user;
  CommunicationRepository? _repository;
  bool _loading = false;
  bool _sending = false;
  String? _error;
  List<CommunicationChannelRecord> _channels = const [];
  String? _selectedChannelId;
  final Map<String, List<CommunicationMessage>> _messagesByChannel = {};
  final Map<String, DateTime> _readMarkersByChannel = {};
  final Map<String, int> _unreadCountsByChannel = {};

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

  int get totalUnreadCount =>
      _unreadCountsByChannel.values.fold<int>(0, (sum, value) => sum + value);

  int unreadCountForChannel(String channelId) =>
      _unreadCountsByChannel[channelId] ?? 0;

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

    _epoch++;
    _user = nextUser;
    _repository = repository;
    _clearWorkspace();
    _error = null;
    _loading = false;
    _sending = false;
    _notify();
    if (nextUser == null) return;

    Future.microtask(load);
  }

  Future<void> load() async {
    final user = _user;
    final repository = _repository;
    if (user == null || repository == null) {
      return;
    }

    final epoch = _epoch;
    _loading = true;
    _error = null;
    _clearWorkspace();
    _notify();
    try {
      await repository.ensureDefaultChannels(user: user);
      if (epoch != _epoch) return;
      final channels = await repository.loadChannels(user: user);
      if (epoch != _epoch) return;
      final readMarkers = await repository.loadReadMarkers(user: user);
      final messages = <String, List<CommunicationMessage>>{};
      for (final channel in channels) {
        if (epoch != _epoch) return;
        messages[channel.channelId] = await repository.loadMessages(
            user: user, channelId: channel.channelId);
      }
      if (epoch != _epoch) return;
      _channels = channels;
      _selectedChannelId = _resolveSelectedChannelId(channels);
      _messagesByChannel
        ..clear()
        ..addAll(messages);
      _readMarkersByChannel
        ..clear()
        ..addAll(readMarkers);
      _recomputeUnreadCounts();
      if (_selectedChannelId != null)
        await _markChannelRead(_selectedChannelId!, notify: false);
    } catch (error) {
      if (epoch == _epoch) {
        _clearWorkspace();
        _error = error.toString();
      }
    } finally {
      if (epoch == _epoch) {
        _loading = false;
        _notify();
      }
    }
  }

  Future<void> selectChannel(String channelId) async {
    final user = _user;
    final repository = _repository;
    final epoch = _epoch;
    if (user == null ||
        repository == null ||
        _selectedChannelId == channelId ||
        !_channels.any((c) => c.channelId == channelId)) return;
    try {
      final messages = _messagesByChannel[channelId] ??
          await repository.loadMessages(user: user, channelId: channelId);
      if (epoch != _epoch) return;
      _messagesByChannel[channelId] = messages;
      _selectedChannelId = channelId;
      await _markChannelRead(channelId, notify: false);
      if (epoch == _epoch) _notify();
    } catch (error) {
      if (epoch == _epoch) {
        _clearWorkspace();
        _error = error.toString();
        _notify();
      }
    }
  }

  Future<bool> createChannel({
    required String name,
    required String description,
    required CommunicationChannelKind kind,
  }) async {
    final user = _user;
    final repository = _repository;
    final trimmedName = name.trim();
    final trimmedDescription = description.trim();
    if (user == null ||
        repository == null ||
        trimmedName.isEmpty ||
        trimmedDescription.isEmpty) {
      return false;
    }

    final epoch = _epoch;
    _sending = true;
    _error = null;
    _notify();

    try {
      final channel = await repository.createChannel(
        user: user,
        name: trimmedName,
        description: trimmedDescription,
        kind: kind,
      );
      if (epoch != _epoch) return false;
      final channels = await repository.loadChannels(user: user);
      if (epoch != _epoch) return false;
      _channels = channels;
      final messages = await repository.loadMessages(
        user: user,
        channelId: channel.channelId,
      );
      if (epoch != _epoch) return false;
      _messagesByChannel[channel.channelId] = messages;
      _selectedChannelId = channel.channelId;
      await _markChannelRead(channel.channelId, notify: false);
      return epoch == _epoch;
    } catch (error) {
      if (epoch == _epoch) {
        _clearWorkspace();
        _error = error.toString();
      }
      return false;
    } finally {
      if (epoch == _epoch) {
        _sending = false;
        _notify();
      }
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

    final epoch = _epoch;
    _sending = true;
    _error = null;
    _notify();

    try {
      await repository.sendMessage(
        user: user,
        channel: channel,
        text: trimmed,
      );
      if (epoch != _epoch) return;
      await _refreshChannel(channel.channelId);
      if (epoch != _epoch) return;
      await _markChannelRead(channel.channelId, notify: false);
    } catch (error) {
      if (epoch == _epoch) {
        _clearWorkspace();
        _error = error.toString();
      }
    } finally {
      if (epoch == _epoch) {
        _sending = false;
        _notify();
      }
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

    final epoch = _epoch;
    _sending = true;
    _error = null;
    _notify();

    try {
      await repository.postAdminAlert(
        user: user,
        text: text.trim(),
        severity: severity,
      );
      if (epoch != _epoch) return;
      await _refreshChannel('admin-alerts');
      if (epoch != _epoch) return;
      if (_selectedChannelId == 'admin-alerts') {
        await _markChannelRead('admin-alerts', notify: false);
      }
    } catch (error) {
      if (epoch == _epoch) {
        _clearWorkspace();
        _error = error.toString();
      }
    } finally {
      if (epoch == _epoch) {
        _sending = false;
        _notify();
      }
    }
  }

  CommunicationRepository _createRepository(RepositoryBackend backend) {
    if (_repositoryFactory != null) return _repositoryFactory(backend);
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
    final epoch = _epoch;
    if (user == null || repository == null) return;
    final channels = await repository.loadChannels(user: user);
    if (epoch != _epoch) return;
    final messages =
        await repository.loadMessages(user: user, channelId: channelId);
    if (epoch != _epoch) return;
    _channels = channels;
    _messagesByChannel[channelId] = messages;
    _recomputeUnreadCounts();
    _selectedChannelId ??= _resolveSelectedChannelId(channels);
  }

  Future<void> _markChannelRead(String channelId, {bool notify = true}) async {
    final user = _user;
    final repository = _repository;
    final epoch = _epoch;
    if (user == null || repository == null) return;
    final messages = _messagesByChannel[channelId] ?? const [];
    final latestMessage =
        messages.isNotEmpty ? messages.last.createdAt : DateTime.now();
    await repository.markChannelRead(
        user: user, channelId: channelId, readAt: latestMessage);
    if (epoch != _epoch) return;
    _readMarkersByChannel[channelId] = latestMessage;
    _recomputeUnreadCounts();
    if (notify) _notify();
  }

  void _recomputeUnreadCounts() {
    final userId = _user?.userId;
    if (userId == null) {
      _unreadCountsByChannel.clear();
      return;
    }

    _unreadCountsByChannel
      ..clear()
      ..addEntries(
        _messagesByChannel.entries.map((entry) {
          final readAt = _readMarkersByChannel[entry.key];
          final unreadCount = entry.value.where((message) {
            final unseen = readAt == null || message.createdAt.isAfter(readAt);
            return unseen && message.authorId != userId;
          }).length;
          return MapEntry(entry.key, unreadCount);
        }),
      );
  }
}
