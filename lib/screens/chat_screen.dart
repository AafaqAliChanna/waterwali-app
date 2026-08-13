import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_message_model.dart';
import '../services/chat_service.dart';
import '../services/chat_socket_service.dart';
import '../services/auth_provider.dart';

class ChatScreen extends StatefulWidget {
  final int orderId;
  const ChatScreen({super.key, required this.orderId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final ChatSocketService _socketService = ChatSocketService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoadingHistory = true;
  String? _historyError;
  List<ChatMessage> _messages = [];
  bool _isSocketConnected = false;
  String? _socketError;

  String? get _token => Provider.of<AuthProvider>(context, listen: false).token;
  int? get _myUserId => Provider.of<AuthProvider>(context, listen: false).userId;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });
    try {
      final messages = await _chatService.getHistory(_token!, widget.orderId);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _isLoadingHistory = false;
      });
      _scrollToBottom();
      _connectSocket();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _historyError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingHistory = false;
      });
    }
  }

  void _connectSocket() {
    _socketService.connect(
      token: _token!,
      orderId: widget.orderId,
      onConnected: () {
        if (!mounted) return;
        setState(() {
          _isSocketConnected = true;
          _socketError = null;
        });
      },
      onMessageReceived: (message) {
        if (!mounted) return;
        setState(() => _messages.add(message));
        _scrollToBottom();
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isSocketConnected = false;
          _socketError = 'Live chat disconnected. Pull to reload.';
        });
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final text = _messageController.text.trim();
    if (text.isEmpty || !_isSocketConnected) return;
    _socketService.sendMessage(widget.orderId, text);
    _messageController.clear();
    // We don't add the message to the list here — it comes back through the
    // /topic subscription just like the other person's messages do, so
    // there's exactly one source of truth and no duplicated bubble.
  }

  @override
  void dispose() {
    _socketService.disconnect();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: const Text('Chat'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
      ),
      body: _isLoadingHistory
          ? const Center(child: CircularProgressIndicator())
          : _historyError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_historyError!, style: const TextStyle(color: Color(0xFFD32F2F))),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _loadHistory, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (_socketError != null)
                      Container(
                        width: double.infinity,
                        color: const Color(0xFFFFF3E0),
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          _socketError!,
                          style: const TextStyle(color: Color(0xFFF57C00), fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    Expanded(
                      child: _messages.isEmpty
                          ? const Center(
                              child: Text('No messages yet. Say hello!',
                                  style: TextStyle(color: Colors.black54)),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(12),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final msg = _messages[index];
                                final isMine = msg.senderId == _myUserId;
                                return Align(
                                  alignment:
                                      isMine ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMine ? const Color(0xFF1E88E5) : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      msg.message,
                                      style: TextStyle(
                                          color: isMine ? Colors.white : Colors.black87),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      color: Colors.white,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                hintText: 'Type a message...',
                                border: OutlineInputBorder(),
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onSubmitted: (_) => _send(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.send, color: Color(0xFF1E88E5)),
                            onPressed: _isSocketConnected ? _send : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}