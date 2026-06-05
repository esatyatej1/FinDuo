import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/finance_provider.dart';
import '../providers/settings_provider.dart';

class AiChatDialog extends StatefulWidget {
  const AiChatDialog({super.key});

  @override
  State<AiChatDialog> createState() => _AiChatDialogState();
}

class _AiChatDialogState extends State<AiChatDialog> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  static const List<String> _quickPrompts = [
    "What's my monthly net balance?",
    "How much have I spent this month?",
    "Which category costs the most?",
    "Summarize my credit card usage",
    "What are my active EMIs?",
    "How much are my fixed bills?",
  ];

  void _sendMessage([String? preset]) async {
    final text = preset ?? _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "content": text});
      _isLoading = true;
    });
    if (preset == null) _controller.clear();
    _scrollToBottom();

    try {
      final response = await context.read<FinanceProvider>().chatWithAi(_messages);
      if (mounted) {
        setState(() {
          _messages.add({"role": "assistant", "content": response});
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            "role": "assistant",
            "content": "I'm sorry, I encountered an error. Please try again."
          });
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
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

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = context.watch<SettingsProvider>().themeColor;
    final isDark = context.watch<SettingsProvider>().themeMode == ThemeMode.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: 480,
        height: 640,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: themeColor.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: themeColor.withValues(alpha: 0.15),
              blurRadius: 30,
              spreadRadius: 5,
            )
          ],
        ),
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: themeColor.withValues(alpha: 0.1))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [themeColor.withValues(alpha: 0.2), themeColor.withValues(alpha: 0.05)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: themeColor.withValues(alpha: 0.3)),
                    ),
                    child: Icon(Icons.auto_awesome, color: themeColor, size: 18),
                  ).animate().scale(duration: 400.ms, curve: Curves.easeOut),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FinDuo Assist',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Powered by Cerebras AI',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  if (_messages.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.refresh_rounded, color: Colors.grey, size: 20),
                      tooltip: 'Clear chat',
                      onPressed: () => setState(() => _messages.clear()),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ── Messages ─────────────────────────────────────────────
            Expanded(
              child: _messages.isEmpty
                  ? _buildEmptyState(themeColor)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isUser = msg['role'] == 'user';
                        return _buildChatBubble(
                          msg['content'],
                          isUser,
                          themeColor,
                          isDark,
                        ).animate().fadeIn(duration: 300.ms).slideY(
                            begin: 0.1, end: 0, curve: Curves.easeOut);
                      },
                    ),
            ),

            // ── Typing Indicator ─────────────────────────────────────
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: themeColor),
                    ),
                    const SizedBox(width: 12),
                    Text('FinDuo Assist is thinking...',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ).animate().fadeIn(),
              ),

            // ── Input ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: themeColor.withValues(alpha: 0.1))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Ask about your finances...',
                        hintStyle: const TextStyle(fontSize: 14),
                        filled: true,
                        fillColor: isDark ? Colors.black26 : Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _isLoading ? null : _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isLoading ? null : () => _sendMessage(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isLoading ? Colors.grey : themeColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fade(duration: 200.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildEmptyState(Color themeColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Icon(Icons.smart_toy_rounded, size: 56, color: themeColor.withValues(alpha: 0.25))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(duration: 2.seconds, begin: const Offset(1, 1), end: const Offset(1.08, 1.08)),
          const SizedBox(height: 16),
          Text('How can I help you?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          Text('Ask me anything about your finances',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 24),
          // Quick prompts
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _quickPrompts.asMap().entries.map((e) {
              return GestureDetector(
                onTap: _isLoading ? null : () => _sendMessage(e.value),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: themeColor.withValues(alpha: 0.2)),
                  ),
                  child: Text(e.value,
                      style: TextStyle(fontSize: 12, color: themeColor, fontWeight: FontWeight.w500)),
                ).animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: e.key * 60)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isUser, Color themeColor, bool isDark) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _copyMessage(text),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: isUser
                ? LinearGradient(
                    colors: [themeColor, themeColor.withValues(alpha: 0.85)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isUser ? null : (isDark ? const Color(0xFF2D3748) : Colors.grey.shade200),
            borderRadius: BorderRadius.circular(16).copyWith(
              bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
              bottomLeft: !isUser ? const Radius.circular(4) : const Radius.circular(16),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: isUser ? Colors.white : (isDark ? Colors.white : Colors.black87),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}
