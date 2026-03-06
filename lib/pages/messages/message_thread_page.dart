// ignore_for_file: use_build_context_synchronously

import 'package:ccr_booking/core/imports.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

class MessageThreadPage extends StatefulWidget {
  final Map<String, dynamic> otherUser;
  final String currentUserId;

  const MessageThreadPage({
    super.key,
    required this.otherUser,
    required this.currentUserId,
  });

  @override
  State<MessageThreadPage> createState() => _MessageThreadPageState();
}

class _MessageThreadPageState extends State<MessageThreadPage>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _messagesScrollController = ScrollController();
  final GlobalKey _threadStackKey = GlobalKey();
  final GlobalKey _messagesViewportKey = GlobalKey();
  final GlobalKey _composerTextFieldKey = GlobalKey();

  RealtimeChannel? _channel;
  RealtimeChannel? _reactionsChannel;
  late final AnimationController _outgoingBubbleController;

  static const String _imagePrefix = '__img__::';
  static const String _mediaBucket = 'profile-pics';
  static final Map<String, List<AppMessage>> _threadCache = {};

  bool _loadingMessages = true;
  bool _sendingMessage = false;
  bool _reactionStorageAvailable = true;
  List<AppMessage> _messages = [];
  Map<String, String> _myReactionsByMessageId = {};
  AppMessage? _editingMessage;
  String? _outgoingBubbleText;
  Rect? _outgoingBubbleStartRect;
  Rect? _outgoingBubbleEndRect;

  String get _otherUserId => (widget.otherUser['id'] ?? '').toString();
  String get _threadKey => '${widget.currentUserId}|$_otherUserId';

  @override
  void initState() {
    super.initState();
    _outgoingBubbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    final cached = _threadCache[_threadKey];
    if (cached != null && cached.isNotEmpty) {
      _messages = List<AppMessage>.from(cached);
      _loadingMessages = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      _loadMyReactionsForMessages(_messages, silent: true);
      _loadMessages(markRead: true);
    } else {
      _loadMessages(markRead: true, showLoader: true);
    }

    _subscribeRealtime();
  }

  String _threadFilter() {
    final me = widget.currentUserId;
    final other = _otherUserId;
    return 'and(sender_id.eq.$me,receiver_id.eq.$other),and(sender_id.eq.$other,receiver_id.eq.$me)';
  }

  void _cacheMessages() {
    _threadCache[_threadKey] = List<AppMessage>.from(_messages);
  }

  void _appendMessage(AppMessage message) {
    final exists = _messages.any((m) => m.id == message.id);
    if (exists) return;

    setState(() {
      _messages = [..._messages, message]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    });
    _cacheMessages();
    _scrollToBottom();
  }

  bool _isMessageInCurrentThread(Map<String, dynamic> row) {
    final senderId = (row['sender_id'] ?? '').toString();
    final receiverId = (row['receiver_id'] ?? '').toString();
    final me = widget.currentUserId;
    final other = _otherUserId;
    return (senderId == me && receiverId == other) ||
        (senderId == other && receiverId == me);
  }

  void _upsertMessageFromRow(Map<String, dynamic> row) {
    if (!_isMessageInCurrentThread(row)) return;

    final updated = AppMessage.fromJson(row);
    final index = _messages.indexWhere((m) => m.id == updated.id);
    if (index < 0) {
      _appendMessage(updated);
      return;
    }

    setState(() {
      final list = List<AppMessage>.from(_messages);
      list[index] = updated;
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _messages = list;
    });
    _cacheMessages();
  }

  void _removeMessageById(String messageId) {
    if (messageId.isEmpty) return;
    final hadMessage = _messages.any((m) => m.id == messageId);
    if (!hadMessage) return;
    setState(() {
      _messages = _messages.where((m) => m.id != messageId).toList();
      _myReactionsByMessageId.remove(messageId);
    });
    _cacheMessages();
  }

  Future<void> _markMessageAsRead(String messageId) async {
    try {
      await _supabase
          .from('messages')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('id', messageId)
          .isFilter('read_at', null);
    } catch (_) {
      // Ignore read receipt failures to keep chat flow smooth.
    }
  }

  void _subscribeRealtime() {
    final me = widget.currentUserId;
    final other = _otherUserId;

    _channel = _supabase
        .channel('thread:$me:$other')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: me,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            final senderId = (row['sender_id'] ?? '').toString();
            final receiverId = (row['receiver_id'] ?? '').toString();

            if (senderId != other || receiverId != me) return;

            final message = AppMessage.fromJson(Map<String, dynamic>.from(row));
            if (!mounted) return;

            _appendMessage(message);
            _markMessageAsRead(message.id);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: me,
          ),
          callback: (payload) {
            if (!mounted) return;
            _upsertMessageFromRow(Map<String, dynamic>.from(payload.newRecord));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'sender_id',
            value: me,
          ),
          callback: (payload) {
            if (!mounted) return;
            _upsertMessageFromRow(Map<String, dynamic>.from(payload.newRecord));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: me,
          ),
          callback: (payload) {
            if (!mounted) return;
            final id = (payload.oldRecord['id'] ?? '').toString();
            _removeMessageById(id);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'sender_id',
            value: me,
          ),
          callback: (payload) {
            if (!mounted) return;
            final id = (payload.oldRecord['id'] ?? '').toString();
            _removeMessageById(id);
          },
        )
        .subscribe();

    if (_reactionStorageAvailable) {
      _reactionsChannel = _supabase
          .channel('message-reactions:$me:$other')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'message_reactions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: me,
            ),
            callback: (_) {
              if (!mounted || _messages.isEmpty) return;
              _loadMyReactionsForMessages(_messages, silent: true);
            },
          )
          .subscribe();
    }
  }

  Future<void> _loadMessages({
    bool markRead = false,
    bool showLoader = false,
  }) async {
    if (_otherUserId.isEmpty) return;

    if (mounted && showLoader) {
      setState(() => _loadingMessages = true);
    }

    try {
      final response = await _supabase
          .from('messages')
          .select('id,sender_id,receiver_id,body,created_at,read_at')
          .or(_threadFilter())
          .order('created_at', ascending: true);

      final loaded = (response as List)
          .map((e) => AppMessage.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      if (markRead) {
        await _supabase
            .from('messages')
            .update({'read_at': DateTime.now().toIso8601String()})
            .eq('sender_id', _otherUserId)
            .eq('receiver_id', widget.currentUserId)
            .isFilter('read_at', null);
      }

      if (!mounted) return;
      await _loadMyReactionsForMessages(loaded, silent: true);
      if (!mounted) return;
      setState(() => _messages = loaded);
      _cacheMessages();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context, 'Error loading messages: $e');
      }
    } finally {
      if (mounted && _loadingMessages) {
        setState(() => _loadingMessages = false);
      }
    }
  }

  Future<void> _loadMyReactionsForMessages(
    List<AppMessage> messages, {
    bool silent = false,
  }) async {
    if (!_reactionStorageAvailable) return;
    if (messages.isEmpty) {
      if (mounted) {
        setState(() => _myReactionsByMessageId = {});
      }
      return;
    }

    final ids = messages.map((m) => m.id).where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return;

    try {
      final data = await _supabase
          .from('message_reactions')
          .select('message_id,emoji')
          .eq('user_id', widget.currentUserId)
          .inFilter('message_id', ids);

      final map = <String, String>{};
      for (final item in List<Map<String, dynamic>>.from(data as List)) {
        final messageId = (item['message_id'] ?? '').toString();
        final emoji = (item['emoji'] ?? '').toString();
        if (messageId.isNotEmpty && emoji.isNotEmpty) {
          map[messageId] = emoji;
        }
      }

      if (mounted) {
        setState(() => _myReactionsByMessageId = map);
      }
    } on PostgrestException catch (e) {
      if (e.code == '42P01' || e.message.contains('message_reactions')) {
        _reactionStorageAvailable = false;
        if (!silent && mounted) {
          CustomSnackBar.show(
            context,
            'Reactions table is missing. Create message_reactions in Supabase.',
          );
        }
        return;
      }
      if (!silent && mounted) {
        CustomSnackBar.show(context, 'Failed to load reactions: ${e.message}');
      }
    } catch (e) {
      if (!silent && mounted) {
        CustomSnackBar.show(context, 'Failed to load reactions: $e');
      }
    }
  }

  Future<void> _setReaction(AppMessage message, String emoji) async {
    if (!_reactionStorageAvailable) {
      CustomSnackBar.show(
        context,
        'Reactions table is missing. Create message_reactions in Supabase.',
      );
      return;
    }

    try {
      await _supabase.from('message_reactions').upsert({
        'message_id': message.id,
        'user_id': widget.currentUserId,
        'emoji': emoji,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'message_id,user_id');

      if (!mounted) return;
      setState(() {
        _myReactionsByMessageId[message.id] = emoji;
      });
    } on PostgrestException catch (e) {
      if (e.code == '42P01' || e.message.contains('message_reactions')) {
        _reactionStorageAvailable = false;
        if (mounted) {
          CustomSnackBar.show(
            context,
            'Reactions table is missing. Create message_reactions in Supabase.',
          );
        }
        return;
      }
      if (mounted) {
        CustomSnackBar.show(context, 'Failed to react: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context, 'Failed to react: $e');
      }
    }
  }

  Future<void> _removeReaction(AppMessage message) async {
    if (!_reactionStorageAvailable) return;

    try {
      await _supabase
          .from('message_reactions')
          .delete()
          .eq('message_id', message.id)
          .eq('user_id', widget.currentUserId);
      if (!mounted) return;
      setState(() {
        _myReactionsByMessageId.remove(message.id);
      });
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context, 'Failed to remove reaction: $e');
      }
    }
  }

  Future<void> _editMessage(AppMessage message) async {
    if (_isImageMessage(message.body)) {
      CustomSnackBar.show(context, 'Image messages cannot be edited.');
      return;
    }
    setState(() {
      _editingMessage = message;
      _messageController.text = message.body;
    });
    _messageFocusNode.requestFocus();
    _scrollToBottom();
  }

  Future<void> _deleteMessage(AppMessage message) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => CustomAlertDialogue(
        icon: AppIcons.trash,
        title: 'Delete Message',
        body: 'Are you sure you want to delete this message?',
        confirm: 'Delete',
      ),
    );

    if (shouldDelete != true) return;

    try {
      await _supabase.from('messages').delete().eq('id', message.id);
      if (!mounted) return;
      _removeMessageById(message.id);
      CustomSnackBar.show(context, 'Message deleted.', color: AppColors.green);
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context, 'Failed to delete message: $e');
      }
    }
  }

  Future<void> _showReactionSheet(AppMessage message) async {
    final options = ['👍', '❤️', '😂', '😮', '😢', '🔥'];
    final current = _myReactionsByMessageId[message.id];
    final isDark = context.isDarkModeRead;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF2F3239) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                  'React to message',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: options.map((emoji) {
                    final selected = current == emoji;
                    return InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await _setReaction(message, emoji);
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : (isDark
                                    ? Colors.white.withValues(alpha: 0.07)
                                    : Colors.black.withValues(alpha: 0.04)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : (isDark ? Colors.white12 : Colors.black12),
                          ),
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (current != null) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await _removeReaction(message);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove reaction'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSenderActionsSheet(AppMessage message) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = sheetContext.isDarkMode;
        final sheetColor = isDark ? AppColors.darkbg : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: Container(
            width: double.infinity,
            color: sheetColor,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Select Image Source',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _buildImageSourceOption(
                        isDark: isDark,
                        imgPath: AppIcons.edit,
                        label: 'Edit',
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          await _editMessage(message);
                        },
                      ),
                      const SizedBox(width: 16),
                      _buildImageSourceOption(
                        isDark: isDark,
                        imgPath: AppIcons.trash,
                        label: 'Delete',
                        color: AppColors.red,
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          await _deleteMessage(message);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onMessageLongPress(AppMessage message) async {
    if (message.senderId == widget.currentUserId) {
      await _showSenderActionsSheet(message);
      return;
    }
    await _showReactionSheet(message);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messagesScrollController.hasClients) return;
      _messagesScrollController.animateTo(
        _messagesScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _runOutgoingBubbleFlight(String text) async {
    final stackContext = _threadStackKey.currentContext;
    final composerContext = _composerTextFieldKey.currentContext;
    final messagesContext = _messagesViewportKey.currentContext;
    if (stackContext == null ||
        composerContext == null ||
        messagesContext == null) {
      return;
    }

    final stackBox = stackContext.findRenderObject();
    final composerBox = composerContext.findRenderObject();
    final messagesBox = messagesContext.findRenderObject();
    if (stackBox is! RenderBox ||
        composerBox is! RenderBox ||
        messagesBox is! RenderBox) {
      return;
    }

    final composerTopLeft = stackBox.globalToLocal(
      composerBox.localToGlobal(Offset.zero),
    );
    final messagesTopLeft = stackBox.globalToLocal(
      messagesBox.localToGlobal(Offset.zero),
    );

    final composerRect = composerTopLeft & composerBox.size;
    final messagesRect = messagesTopLeft & messagesBox.size;
    final normalizedText = text.replaceAll('\n', ' ').trim();
    final preview = normalizedText.length > 48
        ? '${normalizedText.substring(0, 48)}...'
        : normalizedText;

    final estimatedWidth = (preview.length * 8.0).clamp(110.0, 260.0);
    const bubbleHeight = 42.0;
    final maxLeft = stackBox.size.width - estimatedWidth - 8;
    final safeMaxLeft = maxLeft > 8 ? maxLeft : 8.0;

    final startLeft = (composerRect.right - estimatedWidth - 10).clamp(
      8.0,
      safeMaxLeft,
    );
    final startTop =
        composerRect.top + (composerRect.height - bubbleHeight) / 2;

    final endLeft = (messagesRect.right - estimatedWidth - 8).clamp(
      8.0,
      safeMaxLeft,
    );
    final endTop = (messagesRect.bottom - bubbleHeight - 10).clamp(
      8.0,
      stackBox.size.height - bubbleHeight - 8,
    );

    if (!mounted) return;
    if (_outgoingBubbleController.isAnimating) {
      _outgoingBubbleController.stop();
    }

    setState(() {
      _outgoingBubbleText = preview;
      _outgoingBubbleStartRect = Rect.fromLTWH(
        startLeft.toDouble(),
        startTop.toDouble(),
        estimatedWidth.toDouble(),
        bubbleHeight,
      );
      _outgoingBubbleEndRect = Rect.fromLTWH(
        endLeft.toDouble(),
        endTop.toDouble(),
        estimatedWidth.toDouble(),
        bubbleHeight,
      );
    });

    await _outgoingBubbleController.forward(from: 0);
    if (!mounted) return;

    setState(() {
      _outgoingBubbleText = null;
      _outgoingBubbleStartRect = null;
      _outgoingBubbleEndRect = null;
    });
  }

  void _clearOutgoingBubbleFlight() {
    if (!_outgoingBubbleController.isAnimating &&
        _outgoingBubbleText == null &&
        _outgoingBubbleStartRect == null &&
        _outgoingBubbleEndRect == null) {
      return;
    }
    _outgoingBubbleController.stop();
    if (!mounted) return;
    setState(() {
      _outgoingBubbleText = null;
      _outgoingBubbleStartRect = null;
      _outgoingBubbleEndRect = null;
    });
  }

  Future<void> _sendMessage() async {
    if (_sendingMessage) return;

    final body = _messageController.text.trim();
    if (body.isEmpty || _otherUserId.isEmpty) return;

    String? unsentBody;
    setState(() => _sendingMessage = true);
    try {
      final editing = _editingMessage;
      if (editing != null) {
        if (body == editing.body) {
          if (mounted) {
            setState(() => _editingMessage = null);
            _messageController.clear();
          }
          return;
        }

        final updatedRow = await _supabase
            .from('messages')
            .update({'body': body})
            .eq('id', editing.id)
            .select('id,sender_id,receiver_id,body,created_at,read_at')
            .single();

        if (mounted) {
          _upsertMessageFromRow(Map<String, dynamic>.from(updatedRow));
          setState(() => _editingMessage = null);
          _messageController.clear();
          CustomSnackBar.show(
            context,
            'Message updated.',
            color: AppColors.green,
          );
        }
      } else {
        unsentBody = body;
        _messageController.clear();
        final bubbleFlight = _runOutgoingBubbleFlight(body);

        final inserted = await _supabase
            .from('messages')
            .insert({
              'sender_id': widget.currentUserId,
              'receiver_id': _otherUserId,
              'body': body,
            })
            .select('id,sender_id,receiver_id,body,created_at,read_at')
            .single();

        await bubbleFlight;
        final message = AppMessage.fromJson(
          Map<String, dynamic>.from(inserted),
        );

        if (mounted) {
          _appendMessage(message);
        }
      }
    } catch (e) {
      _clearOutgoingBubbleFlight();
      if (unsentBody != null &&
          _editingMessage == null &&
          _messageController.text.trim().isEmpty) {
        _messageController.text = unsentBody;
        _messageController.selection = TextSelection.collapsed(
          offset: _messageController.text.length,
        );
      }
      if (mounted) {
        CustomSnackBar.show(
          context,
          _editingMessage != null ? 'Update failed: $e' : 'Send failed: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _sendingMessage = false);
    }
  }

  void _cancelEditingMessage() {
    setState(() {
      _editingMessage = null;
      _messageController.clear();
    });
    _messageFocusNode.unfocus();
  }

  bool _isImageMessage(String text) => text.startsWith(_imagePrefix);

  String? _extractImageUrl(String text) {
    if (!_isImageMessage(text)) return null;
    final url = text.substring(_imagePrefix.length).trim();
    if (url.isEmpty) return null;
    return url;
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    if (_sendingMessage || _otherUserId.isEmpty) return;

    final picker = ImagePicker();
    XFile? picked;
    try {
      picked = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
        maxHeight: 1600,
      );
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context, 'Image picker failed: $e');
      }
      return;
    }

    if (picked == null) return;

    setState(() => _sendingMessage = true);
    try {
      final ext = p.extension(picked.path).toLowerCase();
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}${ext.isEmpty ? '.jpg' : ext}';
      final filePath =
          'messages/${widget.currentUserId}/$_otherUserId/$fileName';

      await _supabase.storage
          .from(_mediaBucket)
          .upload(
            filePath,
            File(picked.path),
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final publicUrl = _supabase.storage
          .from(_mediaBucket)
          .getPublicUrl(filePath);

      final inserted = await _supabase
          .from('messages')
          .insert({
            'sender_id': widget.currentUserId,
            'receiver_id': _otherUserId,
            'body': '$_imagePrefix$publicUrl',
          })
          .select('id,sender_id,receiver_id,body,created_at,read_at')
          .single();

      final message = AppMessage.fromJson(Map<String, dynamic>.from(inserted));
      if (mounted) {
        _appendMessage(message);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context, 'Image send failed: $e');
      }
    } finally {
      if (mounted) setState(() => _sendingMessage = false);
    }
  }

  Widget _buildImageSourceOption({
    required bool isDark,
    Color? color,
    required String imgPath,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 132,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color ?? (isDark ? Colors.white12 : Colors.black12),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 2),
              IconHandler.buildIcon(
                size: 35,
                color: color ?? (isDark ? Colors.white : Colors.black),
                imagePath: imgPath,
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  color: color ?? (isDark ? Colors.white : Colors.black),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showImageSourceSheet() async {
    if (_sendingMessage) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = sheetContext.isDarkMode;
        final sheetColor = isDark ? AppColors.darkbg : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: Container(
            width: double.infinity,
            color: sheetColor,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Select Image Source',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _buildImageSourceOption(
                        isDark: isDark,
                        imgPath: AppIcons.camera,
                        label: 'Camera',
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _pickAndSendImage(ImageSource.camera);
                        },
                      ),
                      const SizedBox(width: 16),
                      _buildImageSourceOption(
                        isDark: isDark,
                        imgPath: AppIcons.photo,
                        label: 'Photos',
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _pickAndSendImage(ImageSource.gallery);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime.toLocal());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
    _messagesScrollController.dispose();
    _outgoingBubbleController.dispose();
    if (_channel != null) {
      _supabase.removeChannel(_channel!);
    }
    if (_reactionsChannel != null) {
      _supabase.removeChannel(_reactionsChannel!);
    }
    super.dispose();
  }

  Widget _buildMessageBubble(
    AppMessage msg,
    bool isDark, {
    required double maxBubbleWidth,
  }) {
    final isMe = msg.senderId == widget.currentUserId;
    final imageUrl = _extractImageUrl(msg.body);
    final reaction = _myReactionsByMessageId[msg.id];

    return GestureDetector(
      onLongPress: () => _onMessageLongPress(msg),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: maxBubbleWidth),
          decoration: BoxDecoration(
            color: isMe
                ? AppColors.primary.withValues(alpha: 0.2)
                : (isDark ? const Color(0xFF292929) : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isMe
                  ? AppColors.primary.withValues(alpha: 0.6)
                  : (isDark ? Colors.white10 : Colors.black12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (imageUrl != null)
                GestureDetector(
                  onTap: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => Dialog(
                        backgroundColor: Colors.transparent,
                        insetPadding: const EdgeInsets.all(12),
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: isDark ? Colors.black : Colors.white,
                                    padding: const EdgeInsets.all(20),
                                    child: const Text('Failed to load image'),
                                  ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      imageUrl,
                      width: 210,
                      height: 210,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 210,
                        height: 120,
                        alignment: Alignment.center,
                        color: isDark
                            ? const Color(0xFF1F1F1F)
                            : Colors.black12,
                        child: const Text('Image unavailable'),
                      ),
                    ),
                  ),
                )
              else
                Text(
                  msg.body,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 14.5,
                    height: 1.3,
                  ),
                ),
              if (reaction != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  child: Text(reaction, style: const TextStyle(fontSize: 13)),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                _formatTime(msg.createdAt),
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOutgoingBubbleOverlay(bool isDark) {
    final text = _outgoingBubbleText;
    final start = _outgoingBubbleStartRect;
    final end = _outgoingBubbleEndRect;
    if (text == null || start == null || end == null) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _outgoingBubbleController,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(
            _outgoingBubbleController.value,
          );
          final rect = Rect.lerp(start, end, t)!;
          final fadeProgress = ((_outgoingBubbleController.value - 0.78) / 0.22)
              .clamp(0.0, 1.0);
          final opacity = 1 - Curves.easeIn.transform(fadeProgress);
          final scale = 0.94 + (0.06 * t);

          return Positioned(
            left: rect.left,
            top: rect.top,
            width: rect.width,
            height: rect.height,
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.55),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.22),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final name = (widget.otherUser['name'] ?? 'Chat').toString();
    final avatarUrl = widget.otherUser['avatar_url']?.toString();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.secondary : AppColors.primary,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        title: Row(
          children: [
            CustomPfp(
              dimentions: 40,
              fontSize: 20,
              nameOverride: name,
              imageUrlOverride: avatarUrl,
              disableTap: true,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name.replaceFirst(name[0], name[0].toUpperCase()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        key: _threadStackKey,
        children: [
          const CustomBgSvg(),
          LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth;
              final sidePadding = (screenWidth * 0.035).clamp(10.0, 18.0);
              final bubbleMaxWidth = (screenWidth * 0.72).clamp(220.0, 420.0);
              final composerHeight = (screenWidth * 0.125).clamp(46.0, 54.0);
              final actionButtonSize = composerHeight;
              final borderRadius = 50.0;
              final iconPadding = 12.0;

              return Column(
                children: [
                  Expanded(
                    child: Container(
                      key: _messagesViewportKey,
                      child: _loadingMessages
                          ? const Center(child: CustomLoader())
                          : _messages.isEmpty
                          ? Center(
                              child: Text(
                                'No messages yet',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _messagesScrollController,
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                sidePadding,
                                12,
                                sidePadding,
                                12,
                              ),
                              itemCount: _messages.length,
                              itemBuilder: (_, i) => _buildMessageBubble(
                                _messages[i],
                                isDark,
                                maxBubbleWidth: bubbleMaxWidth,
                              ),
                            ),
                    ),
                  ),
                  if (_editingMessage != null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        sidePadding,
                        4,
                        sidePadding,
                        2,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Editing message',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: _cancelEditingMessage,
                              child: Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        sidePadding,
                        8,
                        sidePadding,
                        8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              key: _composerTextFieldKey,
                              constraints: BoxConstraints(
                                minHeight: composerHeight,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF212121)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(
                                  borderRadius,
                                ),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white10
                                      : Colors.black12,
                                ),
                              ),
                              child: TextField(
                                controller: _messageController,
                                focusNode: _messageFocusNode,
                                textInputAction: TextInputAction.send,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                onSubmitted: (_) => _sendMessage(),
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontSize: 14.5,
                                ),
                                decoration: InputDecoration(
                                  hintText: _editingMessage != null
                                      ? 'Edit your message...'
                                      : 'Message ${name.split(" ").first.replaceFirst(name[0], name[0].toUpperCase())}',
                                  hintStyle: TextStyle(
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black45,
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 180),
                            opacity: _editingMessage != null ? 0.45 : 1,
                            child: GestureDetector(
                              onTap: _editingMessage != null
                                  ? null
                                  : _showImageSourceSheet,
                              child: Container(
                                width: actionButtonSize,
                                height: actionButtonSize,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF212121)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(
                                    borderRadius,
                                  ),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white10
                                        : Colors.black12,
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(iconPadding),
                                  child: IconHandler.buildIcon(
                                    imagePath: AppIcons.photo,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _sendMessage,
                            child: Container(
                              width: actionButtonSize,
                              height: actionButtonSize,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(
                                  borderRadius,
                                ),
                              ),
                              child: _sendingMessage
                                  ? Center(
                                      child: CustomLoader(
                                        size: 20,
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Padding(
                                      padding: EdgeInsets.all(iconPadding),
                                      child: IconHandler.buildIcon(
                                        imagePath: _editingMessage != null
                                            ? AppIcons.tick
                                            : AppIcons.send,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          _buildOutgoingBubbleOverlay(isDark),
        ],
      ),
    );
  }
}
