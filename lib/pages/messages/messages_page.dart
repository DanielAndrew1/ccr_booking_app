// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:ccr_booking/core/imports.dart';
import 'package:intl/intl.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _messagesChannel;
  Timer? _refreshDebounce;
  final TextEditingController _searchController = TextEditingController();
  static const String _imagePrefix = '__img__::';
  static final Map<String, List<Map<String, dynamic>>> _threadsCacheByUser = {};

  String? _currentUserId;
  bool _isLoading = true;
  bool _didInitialLoad = false;
  bool _showSearch = false;
  String _searchQuery = '';
  List<Map<String, dynamic>> _threads = [];
  List<Map<String, dynamic>> _allUsers = [];

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

      final users = List<Map<String, dynamic>>.from(usersResponse as List);
      final messages = List<Map<String, dynamic>>.from(
        messagesResponse as List,
      );

      final Map<String, Map<String, dynamic>> userById = {
        for (final u in users) (u['id'] ?? '').toString(): u,
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
          };
        });
      }

      for (final user in users) {
        final id = (user['id'] ?? '').toString();
        threadByOtherUser.putIfAbsent(id, () {
          return {'user': user, 'last_message': '', 'last_at': null};
        });
      }

      final threads = threadByOtherUser.entries.map((entry) {
        final row = Map<String, dynamic>.from(entry.value);
        row['other_user_id'] = entry.key;
        row['unread_count'] = unreadBySender[entry.key] ?? 0;
        return row;
      }).toList();

      threads.sort((a, b) {
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

  String _previewText(String text) {
    if (text.isEmpty) return '';
    if (_isImageMessage(text)) return '[Image]';
    return text;
  }

  List<Map<String, dynamic>> get _visibleThreads {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _threads;
    return _threads.where((thread) {
      final user = Map<String, dynamic>.from(thread['user'] as Map);
      final userName = (user['name'] ?? '').toString().toLowerCase();
      return userName.contains(query);
    }).toList();
  }

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
    _refreshDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildChatRow(Map<String, dynamic> thread, bool isDark) {
    final user = Map<String, dynamic>.from(thread['user'] as Map);
    final userName = (user['name'] ?? 'Unknown').toString();
    final unreadCount = (thread['unread_count'] ?? 0) as int;
    final lastMessage = (thread['last_message'] ?? '').toString();
    final dateLabel = _formatDateTime(thread['last_at'] as DateTime?);
    // final msgExists = lastMessage.isNotEmpty;

    return GestureDetector(
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
                  Text(
                    userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (lastMessage.isNotEmpty) ...[
                    Text(
                      _previewText(lastMessage),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
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
                      color: AppColors.primary,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final visibleThreads = _visibleThreads;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      appBar: CustomAppBar(
        text: 'Messages',
        showPfp: true,
        actions: [
          IconButton(
            onPressed: _toggleSearch,
            icon: IconHandler.buildIcon(imagePath: AppIcons.search),
          ),
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
                child: RefreshIndicator(
                  onRefresh: () => _loadThreads(),
                  color: AppColors.primary,
                  child: _isLoading && _threads.isEmpty
                      ? const Center(child: CustomLoader())
                      : visibleThreads.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 220),
                            Center(
                              child: Text(
                                _searchQuery.isNotEmpty
                                    ? 'No users match your search'
                                    : 'No users available',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                          itemCount: visibleThreads.length,
                          itemBuilder: (_, i) =>
                              _buildChatRow(visibleThreads[i], isDark),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
