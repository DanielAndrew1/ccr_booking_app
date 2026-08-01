// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:ccr_booking/core/imports.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _typingChannel;
  Timer? _refreshDebounce;
  final TextEditingController _searchController = TextEditingController();
  static const String _imagePrefix = '__img__::';
  static const String _voicePrefix = '__voice__::';
  static final Map<String, List<Map<String, dynamic>>> _threadsCacheByUser = {};

  String? _currentUserId;
  bool _isLoading = true;
  bool _didInitialLoad = false;
  bool _showSearch = false;
  bool _showArchived = false;
  String _searchQuery = '';
  List<Map<String, dynamic>> _threads = [];
  List<Map<String, dynamic>> _allUsers = [];

  // otherUserId -> is currently typing to me
  final Map<String, bool> _typingUsers = {};
  final Map<String, Timer> _typingTimers = {};

  @override
  void initState() {
    super.initState();
    _currentUserId = _supabase.auth.currentUser?.id;
    if (_currentUserId == null) {
      _isLoading = false;
      return;
    }
    final cachedThreads = _threadsCacheByUser[_currentUserId!];
    if (cachedThreads != null && cachedThreads.isNotEmpty) {
      _threads = _cloneThreads(cachedThreads);
      _allUsers = _threads
          .map(
            (thread) => Map<String, dynamic>.from(
              thread['user'] as Map<dynamic, dynamic>,
            ),
          )
          .toList();
      _didInitialLoad = true;
      _isLoading = false;
    } else {
      _loadThreads(showLoader: true);
    }
    _subscribeRealtime();
    _subscribeTyping();
  }

  List<Map<String, dynamic>> _cloneThreads(List<Map<String, dynamic>> source) {
    return source.map((thread) {
      final cloned = Map<String, dynamic>.from(thread);
      final user = cloned['user'];
      if (user is Map) {
        cloned['user'] = Map<String, dynamic>.from(
          user.cast<String, dynamic>(),
        );
      }
      return cloned;
    }).toList();
  }

  void _scheduleThreadsRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 250), () {
      _loadThreads();
    });
  }

  void _subscribeRealtime() {
    final userId = _currentUserId;
    if (userId == null) return;

    _messagesChannel = _supabase
        .channel('messages-list:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'sender_id',
            value: userId,
          ),
          callback: (_) => _scheduleThreadsRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: userId,
          ),
          callback: (_) => _scheduleThreadsRefresh(),
        )
        // read receipts: refresh when messages I sent get marked read
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'sender_id',
            value: userId,
          ),
          callback: (_) => _scheduleThreadsRefresh(),
        )
        .subscribe();
  }

  /// Listens for typing broadcasts. The thread/chat page should broadcast on
  /// the SAME channel name ('typing-status') like this whenever the input
  /// text changes:
  ///
  /// Supabase.instance.client.channel('typing-status').sendBroadcastMessage(
  ///   event: 'typing',
  ///   payload: {'from': myUserId, 'to': otherUserId, 'isTyping': true/false},
  /// );
  ///
  /// Send isTyping:true on text change (debounced) and isTyping:false after
  /// ~2s of no typing or when the field is cleared/message sent.
  void _subscribeTyping() {
    final userId = _currentUserId;
    if (userId == null) return;

    _typingChannel = _supabase
        .channel('typing-status')
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            final from = payload['from']?.toString();
            final to = payload['to']?.toString();
            final isTyping = payload['isTyping'] == true;
            if (from == null || to != userId) return;

            _typingTimers[from]?.cancel();
            if (mounted) setState(() => _typingUsers[from] = isTyping);

            if (isTyping) {
              _typingTimers[from] = Timer(const Duration(seconds: 5), () {
                if (mounted) setState(() => _typingUsers[from] = false);
              });
            }
          },
        )
        .subscribe();
  }

  Future<void> _loadThreads({bool showLoader = false}) async {
    final userId = _currentUserId;
    if (userId == null) return;

    if (mounted && showLoader && !_didInitialLoad) {
      setState(() => _isLoading = true);
    }
    try {
      final usersResponse = await _supabase
          .from('users')
          .select('id,name,role,avatar_url')
          .neq('id', userId)
          .order('name');

      final messagesResponse = await _supabase
          .from('messages')
          .select('id,sender_id,receiver_id,body,created_at,read_at')
          .or('sender_id.eq.$userId,receiver_id.eq.$userId')
          .order('created_at', ascending: false);

      final prefsResponse = await _supabase
          .from('chat_preferences')
          .select('other_user_id,pinned,archived,muted')
          .eq('user_id', userId);

      final users = List<Map<String, dynamic>>.from(usersResponse as List);
      final messages = List<Map<String, dynamic>>.from(
        messagesResponse as List,
      );
      final prefs = List<Map<String, dynamic>>.from(prefsResponse as List);

      final Map<String, Map<String, dynamic>> userById = {
        for (final u in users) (u['id'] ?? '').toString(): u,
      };

      final Map<String, Map<String, dynamic>> prefsByUser = {
        for (final p in prefs) (p['other_user_id'] ?? '').toString(): p,
      };

      final Map<String, Map<String, dynamic>> threadByOtherUser = {};
      final Map<String, int> unreadBySender = {};

      for (final m in messages) {
        final senderId = (m['sender_id'] ?? '').toString();
        final receiverId = (m['receiver_id'] ?? '').toString();
        final otherUserId = senderId == userId ? receiverId : senderId;
        if (otherUserId.isEmpty || !userById.containsKey(otherUserId)) continue;

        if (receiverId == userId && (m['read_at'] == null)) {
          unreadBySender[otherUserId] = (unreadBySender[otherUserId] ?? 0) + 1;
        }

        threadByOtherUser.putIfAbsent(otherUserId, () {
          return {
            'user': userById[otherUserId]!,
            'last_message': (m['body'] ?? '').toString(),
            'last_at': DateTime.tryParse((m['created_at'] ?? '').toString()),
            'last_sender_id': senderId,
            'last_read': m['read_at'] != null,
          };
        });
      }

      for (final user in users) {
        final id = (user['id'] ?? '').toString();
        threadByOtherUser.putIfAbsent(id, () {
          return {
            'user': user,
            'last_message': '',
            'last_at': null,
            'last_sender_id': null,
            'last_read': false,
          };
        });
      }

      final threads = threadByOtherUser.entries.map((entry) {
        final row = Map<String, dynamic>.from(entry.value);
        row['other_user_id'] = entry.key;
        row['unread_count'] = unreadBySender[entry.key] ?? 0;
        final pref = prefsByUser[entry.key];
        row['pinned'] = pref?['pinned'] == true;
        row['archived'] = pref?['archived'] == true;
        row['muted'] = pref?['muted'] == true;
        return row;
      }).toList();

      threads.sort((a, b) {
        final aPinned = a['pinned'] == true;
        final bPinned = b['pinned'] == true;
        if (aPinned != bPinned) return aPinned ? -1 : 1;

        final aDate = a['last_at'] as DateTime?;
        final bDate = b['last_at'] as DateTime?;
        if (aDate == null && bDate == null) {
          final aName = ((a['user'] ?? const {})['name'] ?? '')
              .toString()
              .toLowerCase();
          final bName = ((b['user'] ?? const {})['name'] ?? '')
              .toString()
              .toLowerCase();
          return aName.compareTo(bName);
        }
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      if (!mounted) return;
      setState(() {
        _threads = threads;
        _allUsers = users;
        _threadsCacheByUser[userId] = _cloneThreads(threads);
        _didInitialLoad = true;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context, 'Error loading chats: $e');
      }
    } finally {
      if (mounted && showLoader) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateChatPref(
    String otherUserId, {
    bool? pinned,
    bool? archived,
    bool? muted,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return;

    final thread = _threads.firstWhere(
      (t) => t['other_user_id'] == otherUserId,
      orElse: () => {},
    );
    if (thread.isEmpty) return;

    final newPinned = pinned ?? (thread['pinned'] == true);
    final newArchived = archived ?? (thread['archived'] == true);
    final newMuted = muted ?? (thread['muted'] == true);

    setState(() {
      thread['pinned'] = newPinned;
      thread['archived'] = newArchived;
      thread['muted'] = newMuted;
      _threads.sort((a, b) {
        final aPinned = a['pinned'] == true;
        final bPinned = b['pinned'] == true;
        if (aPinned != bPinned) return aPinned ? -1 : 1;
        final aDate = a['last_at'] as DateTime?;
        final bDate = b['last_at'] as DateTime?;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
      _threadsCacheByUser[userId] = _cloneThreads(_threads);
    });

    try {
      await _supabase.from('chat_preferences').upsert(
        {
          'user_id': userId,
          'other_user_id': otherUserId,
          'pinned': newPinned,
          'archived': newArchived,
          'muted': newMuted,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,other_user_id',
      );
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context, 'Failed to update chat: $e');
      }
    }
  }

  void _showChatOptions(Map<String, dynamic> thread) {
    final isDark = context.isDarkMode;
    final otherUserId = (thread['other_user_id'] ?? '').toString();
    final pinned = thread['pinned'] == true;
    final archived = thread['archived'] == true;
    final muted = thread['muted'] == true;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              ListTile(
                leading: Icon(
                  pinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                title: Text(
                  pinned ? 'Unpin chat' : 'Pin chat',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _updateChatPref(otherUserId, pinned: !pinned);
                },
              ),
              ListTile(
                leading: Icon(
                  muted ? Icons.notifications_off : Icons.notifications_off_outlined,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                title: Text(
                  muted ? 'Unmute notifications' : 'Mute notifications',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _updateChatPref(otherUserId, muted: !muted);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.archive_outlined,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                title: Text(
                  archived ? 'Unarchive chat' : 'Archive chat',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _updateChatPref(otherUserId, archived: !archived);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final local = dateTime.toLocal();
    final isToday =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (isToday) return DateFormat('h:mm a').format(local);
    return DateFormat('dd/MM').format(local);
  }

  bool _isImageMessage(String text) => text.startsWith(_imagePrefix);
  bool _isVoiceMessage(String text) => text.startsWith(_voicePrefix);

  String _previewText(String text) {
    if (text.isEmpty) return '';
    if (_isImageMessage(text)) return '[Image]';
    if (_isVoiceMessage(text)) return '[Voice message]';
    return text;
  }

  List<Map<String, dynamic>> get _visibleThreads {
    final query = _searchQuery.trim().toLowerCase();
    final base = _threads.where((t) => (t['archived'] == true) == _showArchived);
    if (query.isEmpty) return base.toList();
    return base.where((thread) {
      final user = Map<String, dynamic>.from(thread['user'] as Map);
      final userName = (user['name'] ?? '').toString().toLowerCase();
      return userName.contains(query);
    }).toList();
  }

  int get _archivedCount => _threads.where((t) => t['archived'] == true).length;

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  Future<void> _showCreateGroupSheet() async {
    final me = _currentUserId;
    if (me == null) return;
    if (_allUsers.isEmpty) {
      CustomSnackBar.show(context, 'No users available for group creation.');
      return;
    }

    final groupNameController = TextEditingController();
    final selectedUserIds = <String>{};
    bool isCreating = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = sheetContext.isDarkMode;
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            final sortedUsers = [..._allUsers]
              ..sort(
                (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo(
                  (b['name'] ?? '').toString().toLowerCase(),
                ),
              );
            return Container(
              height: _allUsers.toList().length.ceilToDouble() * 250,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Create Group',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: groupNameController,
                      textCapitalization: TextCapitalization.words,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Group name',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Select members',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.separated(
                        itemCount: sortedUsers.length,
                        separatorBuilder: (_, index) => Divider(
                          height: 1,
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                        itemBuilder: (_, i) {
                          final user = sortedUsers[i];
                          final userId = (user['id'] ?? '').toString();
                          final userName = (user['name'] ?? 'Unknown')
                              .toString();
                          final avatarUrl = user['avatar_url']?.toString();
                          final selected = selectedUserIds.contains(userId);
                          return InkWell(
                            onTap: () {
                              setModalState(() {
                                if (selected) {
                                  selectedUserIds.remove(userId);
                                } else {
                                  selectedUserIds.add(userId);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 2,
                              ),
                              child: Row(
                                children: [
                                  CustomPfp(
                                    dimentions: 40,
                                    fontSize: 20,
                                    nameOverride: userName,
                                    imageUrlOverride: avatarUrl,
                                    disableTap: true,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      userName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Checkbox(
                                    value: selected,
                                    onChanged: (_) {
                                      setModalState(() {
                                        if (selected) {
                                          selectedUserIds.remove(userId);
                                        } else {
                                          selectedUserIds.add(userId);
                                        }
                                      });
                                    },
                                    activeColor: AppColors.primary,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    CustomButton(
                      text: isCreating ? 'Creating Group...' : 'Create Group',
                      onPressed: isCreating
                          ? null
                          : () async {
                              final name = groupNameController.text.trim();
                              if (name.isEmpty) {
                                CustomSnackBar.show(
                                  context,
                                  'Please enter a group name.',
                                );
                                return;
                              }
                              if (selectedUserIds.length < 2) {
                                CustomSnackBar.show(
                                  context,
                                  'Select at least 2 users for a group.',
                                );
                                return;
                              }

                              setModalState(() => isCreating = true);
                              try {
                                final groupRow = await _supabase
                                    .from('message_groups')
                                    .insert({
                                      'name': name,
                                      'created_by': me,
                                      'created_at': DateTime.now()
                                          .toIso8601String(),
                                    })
                                    .select('id')
                                    .single();
                                final groupId = (groupRow['id'] ?? '')
                                    .toString();
                                if (groupId.isEmpty) {
                                  throw Exception('Group id missing.');
                                }

                                final memberRows = <Map<String, dynamic>>[
                                  {
                                    'group_id': groupId,
                                    'user_id': me,
                                    'added_by': me,
                                    'created_at': DateTime.now()
                                        .toIso8601String(),
                                  },
                                  ...selectedUserIds.map(
                                    (id) => {
                                      'group_id': groupId,
                                      'user_id': id,
                                      'added_by': me,
                                      'created_at': DateTime.now()
                                          .toIso8601String(),
                                    },
                                  ),
                                ];

                                await _supabase
                                    .from('message_group_members')
                                    .insert(memberRows);

                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                                if (mounted) {
                                  CustomSnackBar.show(
                                    context,
                                    'Group created successfully.',
                                    color: AppColors.green,
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  CustomSnackBar.show(
                                    context,
                                    'Create group failed: $e',
                                  );
                                }
                                if (sheetContext.mounted) {
                                  setModalState(() => isCreating = false);
                                }
                              }
                            },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    groupNameController.dispose();
  }

  @override
  void dispose() {
    if (_messagesChannel != null) {
      _supabase.removeChannel(_messagesChannel!);
    }
    if (_typingChannel != null) {
      _supabase.removeChannel(_typingChannel!);
    }
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _refreshDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildReadReceipt(Map<String, dynamic> thread, bool isDark) {
    if (thread['last_sender_id'] != _currentUserId) return const SizedBox.shrink();
    final read = thread['last_read'] == true;
    return Padding(
      padding: const EdgeInsets.only(right: 3),
      child: Icon(
        read ? Icons.done_all_rounded : Icons.done_all_rounded,
        size: 15,
        color: read
            ? (isDark ? AppColors.primary : AppColors.secondary)
            : (isDark ? Colors.white38 : Colors.black38),
      ),
    );
  }

  Widget _buildChatRow(Map<String, dynamic> thread, bool isDark) {
    final user = Map<String, dynamic>.from(thread['user'] as Map);
    final userName = (user['name'] ?? 'Unknown').toString();
    final otherUserId = (thread['other_user_id'] ?? '').toString();
    final unreadCount = (thread['unread_count'] ?? 0) as int;
    final lastMessage = (thread['last_message'] ?? '').toString();
    final dateLabel = _formatDateTime(thread['last_at'] as DateTime?);
    final muted = thread['muted'] == true;
    final pinned = thread['pinned'] == true;
    final isTyping = _typingUsers[otherUserId] == true;

    return Slidable(
      key: ValueKey(otherUserId),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) => _updateChatPref(
              otherUserId,
              archived: !(thread['archived'] == true),
            ),
            backgroundColor: const Color(0xFF6B8E9C),
            foregroundColor: Colors.white,
            icon: Icons.archive_outlined,
            label: thread['archived'] == true ? 'Unarchive' : 'Archive',
            borderRadius: BorderRadius.circular(14),
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) => _updateChatPref(otherUserId, pinned: !pinned),
            backgroundColor: const Color(0xFFDDA15E),
            foregroundColor: Colors.white,
            icon: pinned ? Icons.push_pin : Icons.push_pin_outlined,
            label: pinned ? 'Unpin' : 'Pin',
            borderRadius: BorderRadius.circular(14),
          ),
          SlidableAction(
            onPressed: (_) => _updateChatPref(otherUserId, muted: !muted),
            backgroundColor: const Color(0xFF6C757D),
            foregroundColor: Colors.white,
            icon: muted ? Icons.notifications_off : Icons.notifications_off_outlined,
            label: muted ? 'Unmute' : 'Mute',
            borderRadius: BorderRadius.circular(14),
          ),
        ],
      ),
      child: GestureDetector(
      onTap: () async {
        setState(() {
          thread['unread_count'] = 0;
          final userId = _currentUserId;
          if (userId != null) {
            _threadsCacheByUser[userId] = _cloneThreads(_threads);
          }
        });
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MessageThreadPage(
              otherUser: user,
              currentUserId: _currentUserId!,
            ),
          ),
        );
      },
      onLongPress: () => _showChatOptions(thread),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Color(0xFF2D2D2D).withOpacity(0.6)
              : Color(0xFFD0C9C9).withOpacity(0.6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CustomPfp(
              dimentions: 48,
              fontSize: 22,
              nameOverride: userName,
              imageUrlOverride: user['avatar_url']?.toString(),
              disableTap: true,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (pinned) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.push_pin,
                          size: 13,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ],
                      if (muted) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.notifications_off,
                          size: 13,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ],
                    ],
                  ),
                  if (isTyping)
                    Text(
                      'typing...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13.5,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else if (lastMessage.isNotEmpty)
                    Row(
                      children: [
                        _buildReadReceipt(thread, isDark),
                        Flexible(
                          child: Text(
                            _previewText(lastMessage),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: unreadCount > 0
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : (isDark ? Colors.white60 : Colors.black54),
                              fontSize: 13.5,
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (dateLabel.isNotEmpty)
                  Text(
                    dateLabel,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontSize: 11.5,
                    ),
                  ),
                const SizedBox(height: 6),
                if (unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: muted
                          ? (isDark ? Colors.white24 : Colors.black26)
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildArchivedBanner(bool isDark) {
    return InkWell(
      onTap: () => setState(() => _showArchived = true),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Color(0xFF2D2D2D).withOpacity(0.6)
              : Color(0xFFD0C9C9).withOpacity(0.6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.archive_outlined, color: isDark ? Colors.white70 : Colors.black54),
            const SizedBox(width: 10),
            Text(
              'Archived',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            Text(
              '$_archivedCount',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final visibleThreads = _visibleThreads;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      appBar: CustomAppBar(
        text: _showArchived ? 'Archived' : 'Messages',
        showPfp: !_showArchived,
        actions: [
          IconButton(
            onPressed: _toggleSearch,
            icon: IconHandler.buildIcon(imagePath: AppIcons.search),
          ),
          if (!_showArchived)
            IconButton(
              onPressed: _showCreateGroupSheet,
              icon: IconHandler.buildIcon(imagePath: AppIcons.add),
            ),
        ],
      ),
      body: Stack(
        children: [
          const CustomBgSvg(),
          Column(
            children: [
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: _showSearch
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1F1F1F)
                          : Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search users',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                        icon: Icon(
                          Icons.search_rounded,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ),
                  ),
                ),
                secondChild: const SizedBox.shrink(),
              ),
              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    CupertinoSliverRefreshControl(
                      onRefresh: () => _loadThreads(),
                      builder:
                          (
                            context,
                            refreshState,
                            pulledExtent,
                            refreshTriggerPullDistance,
                            refreshIndicatorExtent,
                          ) => const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: CustomLoader(size: 24),
                            ),
                          ),
                    ),
                    if (_isLoading && _threads.isEmpty)
                      const SliverFillRemaining(
                        child: Center(child: CustomLoader()),
                      )
                    else if (visibleThreads.isEmpty && !(_archivedCount > 0 && !_showArchived))
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            _searchQuery.isNotEmpty
                                ? 'No users match your search'
                                : (_showArchived ? 'No archived chats' : 'No users available'),
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              if (!_showArchived &&
                                  _archivedCount > 0 &&
                                  _searchQuery.isEmpty &&
                                  index == 0) {
                                return _buildArchivedBanner(isDark);
                              }
                              final offset =
                                  (!_showArchived && _archivedCount > 0 && _searchQuery.isEmpty)
                                      ? 1
                                      : 0;
                              return _buildChatRow(
                                visibleThreads[index - offset],
                                isDark,
                              );
                            },
                            childCount: visibleThreads.length +
                                ((!_showArchived && _archivedCount > 0 && _searchQuery.isEmpty)
                                    ? 1
                                    : 0),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}