import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/theme/app_colors.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/animated_background.dart';
import '../../services/api_service.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();

  bool isLoading = false;

  // ── Speech to Text ────────────────────────────
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;

  // ── Text to Speech ────────────────────────────
  final FlutterTts _tts = FlutterTts();
  String? _speakingMessageId; // which message is currently being spoken

  // ── Mic pulse animation ───────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── Conversation ──────────────────────────────
  List<Map<String, String>> conversationHistory = [];
  List<Map<String, String>> messages = [
    {
      "role": "ai",
      "id":   "welcome",
      "text":
          "👋 Hello! I'm **DevOpsGPT AI**\n\nI have access to your real server data. Ask me:\n• *\"Summarize my alerts\"*\n• *\"What's wrong with my servers?\"*\n• *\"Why is CPU high?\"*\n• *\"Show recent logs\"*\n\n🎤 You can also **tap the mic** to speak!"
    }
  ];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initSpeech() async {
    // Request mic permission on Android before initializing
    final status = await Permission.microphone.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (mounted) setState(() => _speechEnabled = false);
      return;
    }
    _speechEnabled = await _speech.initialize(
      onStatus: (status) {},
      onError:  (error) {},
    );
    if (mounted) setState(() {});
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speakingMessageId = null);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _speakingMessageId = null);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.stop();
    _tts.stop();
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  // ── Mic (popup only — inline listener removed) ─

  // ── Strip markdown for clean TTS ─────────────
  String _stripMarkdown(String text) {
    return text
        .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m[1] ?? '')
        .replaceAllMapped(RegExp(r'\*(.+?)\*'),     (m) => m[1] ?? '')
        .replaceAllMapped(RegExp(r'`(.+?)`'),        (m) => m[1] ?? '')
        .replaceAllMapped(RegExp(r'\[(.+?)\]\(.+?\)'), (m) => m[1] ?? '')
        .replaceAll(RegExp(r'#+\s?'), '')
        .replaceAll(RegExp(r'^\s*[-*]\s', multiLine: true), '')
        // Remove AWS server IDs like i-0abc123def456789
        .replaceAll(RegExp(r'\bi-[0-9a-f]{8,17}\b'), '')
        // Remove other common AWS resource IDs
        .replaceAll(RegExp(r'\b[a-z]+-[0-9a-f]{8,}\b'), '')
        .replaceAll('•', '')
        .replaceAll('`', '')
        .replaceAll('*', '')
        .replaceAll('#', '')
        // Clean up extra spaces/colons left after ID removal
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(RegExp(r':\s*,'), ',')
        .replaceAll(RegExp(r':\s*\.'), '.')
        .trim();
  }

  // ── TTS toggle ────────────────────────────────
  Future<void> _toggleSpeak(String messageId, String text) async {
    if (_speakingMessageId == messageId) {
      await _tts.stop();
      setState(() => _speakingMessageId = null);
    } else {
      await _tts.stop();
      setState(() => _speakingMessageId = messageId);
      // Strip markdown for cleaner speech
      final plainText = _stripMarkdown(text);
      await _tts.speak(plainText);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.darkCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Send message ──────────────────────────────
  void scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> sendMessage() async {
    if (controller.text.trim().isEmpty) return;

    final userMsg = controller.text.trim();
    controller.clear();

    setState(() {
      messages.add({
        "role": "user",
        "id":   DateTime.now().millisecondsSinceEpoch.toString(),
        "text": userMsg,
      });
      isLoading = true;
    });
    scrollToBottom();

    conversationHistory.add({'role': 'user', 'content': userMsg});

    try {
      final response = await ApiService
          .sendAiMessageWithHistory(userMsg, conversationHistory);

      Map<String, dynamic> aiData = response;
      if (response.containsKey('body') && response['body'] is String) {
        aiData = jsonDecode(response['body']) as Map<String, dynamic>;
      }

      final aiReply = aiData['explanation'] ??
          '${aiData['root_cause'] ?? ''}\nFix: ${aiData['suggested_fix'] ?? ''}';

      conversationHistory.add({'role': 'assistant', 'content': aiReply});

      final msgId = DateTime.now().millisecondsSinceEpoch.toString();
      setState(() {
        messages.add({"role": "ai", "id": msgId, "text": aiReply});
        isLoading = false;
      });
      scrollToBottom();
    } catch (e) {
      conversationHistory.removeLast();
      setState(() {
        messages.add({
          "role": "ai",
          "id":   DateTime.now().millisecondsSinceEpoch.toString(),
          "text": "⚠️ Connection error. Please try again.\n\n*Error: $e*",
        });
        isLoading = false;
      });
      scrollToBottom();
    }
  }

  // ── Build ─────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final textPrimary   = AppTheme.textPrimary(context);
    final textMuted     = AppTheme.textMuted(context);
    final textSecondary = AppTheme.textSecondary(context);

    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [

              // ── App Bar ───────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: AppColors.primaryGradient),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.smart_toy_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AI Assistant',
                              style: GoogleFonts.inter(
                                  color: textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          Row(children: [
                            Text('DevOpsGPT · Voice Ready',
                                style: GoogleFonts.inter(
                                    color: textMuted, fontSize: 10)),
                            const SizedBox(width: 4),
                            Icon(Icons.mic_rounded,
                                color: _speechEnabled
                                    ? AppColors.success
                                    : AppColors.textMuted,
                                size: 10),
                          ]),
                        ],
                      ),
                    ]),
                    GestureDetector(
                      onTap: () {
                        _tts.stop();
                        setState(() {
                          messages = [
                            {
                              "role": "ai",
                              "id":   "welcome",
                              "text": "👋 Hello! I'm **DevOpsGPT AI**\n\nI have access to your real server data. Ask me anything!\n\n🎤 Tap the **mic button** (bottom right) to use voice!"
                            }
                          ];
                          conversationHistory  = [];
                          _speakingMessageId   = null;
                        });
                      },
                      child: GlassCard(
                        padding: const EdgeInsets.all(8),
                        borderRadius: 20,
                        child: const Icon(Icons.refresh_rounded,
                            color: AppColors.accent, size: 18),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Quick chips ───────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  _quickChip(context, '📊 Summarize alerts'),
                  _quickChip(context, '🔴 Why CPU high?'),
                  _quickChip(context, '📋 Recent logs'),
                  _quickChip(context, '🖥️ Server status'),
                  _quickChip(context, '🔧 Available fixes'),
                ]),
              ),

              const SizedBox(height: 8),

              // ── Messages ──────────────────────
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg    = messages[index];
                    final isUser = msg["role"] == "user";
                    return _buildMessage(
                      context,
                      id:     msg["id"] ?? index.toString(),
                      text:   msg["text"]!,
                      isUser: isUser,
                    );
                  },
                ),
              ),

              // ── Loading ───────────────────────
              if (isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: Row(children: [
                    GlassCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(children: [
                        SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accent),
                        ),
                        const SizedBox(width: 10),
                        Text('AI thinking...',
                            style: TextStyle(
                                color: textSecondary,
                                fontSize: 13)),
                      ]),
                    ),
                  ]),
                ),

              // ── Input bar ─────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(children: [
                    // Text field
                    Expanded(
                      child: TextField(
                        controller: controller,
                        style: TextStyle(
                            color: textPrimary, fontSize: 14),
                        onSubmitted: (_) => sendMessage(),
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: 'Ask about your servers…',
                          hintStyle: TextStyle(
                              color: textMuted, fontSize: 14),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Mic button
                    GestureDetector(
                      onTap: _openVoicePopup,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accent
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.accent
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(Icons.mic_rounded,
                            color: AppColors.accent, size: 18),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Send button
                    GestureDetector(
                      onTap: isLoading ? null : sendMessage,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: isLoading
                              ? null
                              : const LinearGradient(
                                  colors: AppColors.primaryGradient),
                          color: isLoading ? textMuted : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Voice popup ───────────────────────────────
  void _openVoicePopup() {
    if (!_speechEnabled) {
      _showSnack('Microphone not available on this device');
      return;
    }

    // State inside the popup
    String popupText    = '';
    bool   popupListening = false;
    bool   popupLoading   = false;
    String popupReply   = '';
    bool   popupSpeaking  = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setPopup) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final textPrimary   = AppTheme.textPrimary(ctx);
          final textMuted     = AppTheme.textMuted(ctx);
          final dialogBg = isDark
              ? const Color(0xFF0D1424).withValues(alpha: 0.97)
              : Colors.white.withValues(alpha: 0.97);

          // ── Start listening inside popup ──────
          Future<void> startListening() async {
            setPopup(() {
              popupListening = true;
              popupText      = '';
              popupReply     = '';
            });

            await _speech.listen(
              onResult: (result) {
                setPopup(() => popupText = result.recognizedWords);
              },
              listenFor: const Duration(seconds: 30),
              pauseFor: const Duration(seconds: 3),
              localeId: 'en_US',
              onSoundLevelChange: null,
            );

            // Poll for done status
            Future.doWhile(() async {
              await Future.delayed(const Duration(milliseconds: 300));
              if (!_speech.isListening) {
                if (!ctx.mounted) return false;
                setPopup(() => popupListening = false);
                if (popupText.isNotEmpty) {
                  setPopup(() => popupLoading = true);
                  conversationHistory.add(
                      {'role': 'user', 'content': popupText});
                  setState(() {
                    messages.add({
                      "role": "user",
                      "id":   DateTime.now().millisecondsSinceEpoch.toString(),
                      "text": popupText,
                    });
                  });
                  try {
                    final response = await ApiService
                        .sendAiMessageWithHistory(
                            popupText, conversationHistory);
                    Map<String, dynamic> aiData = response;
                    if (response.containsKey('body') &&
                        response['body'] is String) {
                      aiData = jsonDecode(response['body'])
                          as Map<String, dynamic>;
                    }
                    final reply = aiData['explanation'] ??
                        '${aiData['root_cause'] ?? ''}\nFix: ${aiData['suggested_fix'] ?? ''}';
                    conversationHistory.add(
                        {'role': 'assistant', 'content': reply});
                    final msgId =
                        DateTime.now().millisecondsSinceEpoch.toString();
                    setState(() {
                      messages.add({
                        "role": "ai",
                        "id":   msgId,
                        "text": reply,
                      });
                    });
                    scrollToBottom();
                    if (!ctx.mounted) return false;
                    setPopup(() {
                      popupLoading  = false;
                      popupReply    = reply;
                      popupSpeaking = true;
                    });
                    // Auto-speak the reply
                    final plain = _stripMarkdown(reply);
                    await _tts.speak(plain);
                    _tts.setCompletionHandler(() {
                      if (ctx.mounted) {
                        setPopup(() => popupSpeaking = false);
                      }
                    });
                  } catch (e) {
                    conversationHistory.removeLast();
                    if (!ctx.mounted) return false;
                    setPopup(() {
                      popupLoading = false;
                      popupReply   = '⚠️ Error: $e';
                    });
                  }
                }
                return false; // stop polling
              }
              return true; // keep polling
            });
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 60),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  // Max height so it never overflows screen
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.78,
                  ),
                  decoration: BoxDecoration(
                    color: dialogBg,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      // ── Fixed header ──────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                      colors: AppColors.primaryGradient),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.mic_rounded,
                                    color: Colors.white, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Text('Voice Assistant',
                                  style: GoogleFonts.inter(
                                    color: textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  )),
                            ]),
                            GestureDetector(
                              onTap: () {
                                _speech.stop();
                                _tts.stop();
                                Navigator.pop(ctx);
                              },
                              child: Icon(Icons.close_rounded,
                                  color: textMuted, size: 22),
                            ),
                          ],
                        ),
                      ),

                      // ── Fixed mic orb + status ─
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: popupLoading
                                  ? null
                                  : () async {
                                      if (popupListening) {
                                        await _speech.stop();
                                        setPopup(() =>
                                            popupListening = false);
                                      } else {
                                        await startListening();
                                      }
                                    },
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 300),
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: popupListening
                                      ? const LinearGradient(
                                          colors: AppColors.primaryGradient,
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight)
                                      : null,
                                  color: popupListening
                                      ? null
                                      : AppColors.accent
                                          .withValues(alpha: 0.1),
                                  border: Border.all(
                                    color: popupListening
                                        ? AppColors.accent
                                        : AppColors.accent
                                            .withValues(alpha: 0.3),
                                    width: popupListening ? 3 : 1.5,
                                  ),
                                  boxShadow: popupListening
                                      ? [
                                          BoxShadow(
                                            color: AppColors.accent
                                                .withValues(alpha: 0.4),
                                            blurRadius: 30,
                                            spreadRadius: 8,
                                          )
                                        ]
                                      : null,
                                ),
                                child: popupLoading
                                    ? const Center(
                                        child: SizedBox(
                                          width: 32, height: 32,
                                          child: CircularProgressIndicator(
                                            color: AppColors.accent,
                                            strokeWidth: 3,
                                          ),
                                        ),
                                      )
                                    : ScaleTransition(
                                        scale: popupListening
                                            ? _pulseAnimation
                                            : const AlwaysStoppedAnimation(1.0),
                                        child: Icon(
                                          popupListening
                                              ? Icons.mic_rounded
                                              : Icons.mic_none_rounded,
                                          color: popupListening
                                              ? Colors.white
                                              : AppColors.accent,
                                          size: 44,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              popupLoading
                                  ? 'AI is thinking…'
                                  : popupListening
                                      ? 'Listening… tap to stop'
                                      : popupReply.isNotEmpty
                                          ? 'Tap mic to ask again'
                                          : 'Tap mic to speak',
                              style: GoogleFonts.inter(
                                  color: textMuted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),

                      // ── Scrollable content ─────
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [

                              // Transcribed text
                              if (popupText.isNotEmpty) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.accent
                                          .withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.person_rounded,
                                          color: AppColors.accent,
                                          size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(popupText,
                                            style: TextStyle(
                                              color: textPrimary,
                                              fontSize: 13,
                                              fontStyle: FontStyle.italic,
                                            )),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // AI reply — full text, scrollable
                              if (popupReply.isNotEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.purple
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.purple
                                          .withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Header row with icon + stop/play
                                      Row(
                                        children: [
                                          Icon(Icons.smart_toy_rounded,
                                              color: AppColors.purple,
                                              size: 16),
                                          const SizedBox(width: 6),
                                          Text('AI Response',
                                              style: TextStyle(
                                                color: AppColors.purple,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              )),
                                          const Spacer(),
                                          // Speaking indicator
                                          if (popupSpeaking)
                                            Padding(
                                              padding: const EdgeInsets.only(right: 6),
                                              child: SizedBox(
                                                width: 14, height: 14,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: AppColors.purple,
                                                ),
                                              ),
                                            ),
                                          GestureDetector(
                                            onTap: () async {
                                              if (popupSpeaking) {
                                                await _tts.stop();
                                                setPopup(() =>
                                                    popupSpeaking = false);
                                              } else {
                                                setPopup(() =>
                                                    popupSpeaking = true);
                                                final plain = _stripMarkdown(popupReply);
                                                await _tts.speak(plain);
                                                _tts.setCompletionHandler(() {
                                                  if (ctx.mounted) {
                                                    setPopup(() =>
                                                        popupSpeaking = false);
                                                  }
                                                });
                                              }
                                            },
                                            child: Icon(
                                              popupSpeaking
                                                  ? Icons.stop_circle_rounded
                                                  : Icons.volume_up_rounded,
                                              color: AppColors.purple,
                                              size: 20,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // Full reply text — no truncation
                                      Text(
                                        popupReply,
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontSize: 13,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ).then((_) {
      // Clean up when popup closes
      _speech.stop();
      _tts.stop();
    });
  }

  // ── Message bubble ────────────────────────────
  Widget _buildMessage(
    BuildContext context, {
    required String id,
    required String text,
    required bool isUser,
  }) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppTheme.textPrimary(context);
    final glassBorder = AppTheme.glassBorder(context);
    final aiBubbleBg  = isDark
        ? AppColors.darkGlassWhite
        : const Color(0xFFFFFFFF);
    final codeBlockBg = isDark
        ? Colors.black.withValues(alpha: 0.4)
        : const Color(0xFFE8EDF5);
    final isSpeaking  = _speakingMessageId == id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // AI avatar
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: AppColors.primaryGradient),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? const LinearGradient(
                            colors: AppColors.primaryGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isUser ? null : aiBubbleBg,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: isUser
                        ? null
                        : Border.all(color: glassBorder),
                    boxShadow: isUser
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ],
                  ),
                  child: isUser
                      ? Text(text,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14))
                      : MarkdownBody(
                          data: text,
                          shrinkWrap: true,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                                color: textPrimary,
                                fontSize: 14,
                                height: 1.5),
                            h1: GoogleFonts.inter(
                                color: textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                            h2: GoogleFonts.inter(
                                color: textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                            h3: GoogleFonts.inter(
                                color: AppColors.accent,
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                            strong: TextStyle(
                                color: isDark
                                    ? AppColors.accent
                                    : AppColors.purple,
                                fontWeight: FontWeight.bold),
                            em: TextStyle(
                                color: AppTheme.textSecondary(context),
                                fontStyle: FontStyle.italic),
                            code: TextStyle(
                                color: AppColors.accent,
                                backgroundColor: codeBlockBg,
                                fontSize: 12,
                                fontFamily: 'monospace'),
                            codeblockDecoration: BoxDecoration(
                              color: codeBlockBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            listBullet: const TextStyle(
                                color: AppColors.accent),
                            blockquote: TextStyle(
                                color: AppTheme.textSecondary(context)),
                          ),
                        ),
                ),

                // ── Speaker button (AI only) ──
                if (!isUser) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _toggleSpeak(id, text),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSpeaking
                            ? AppColors.accent.withValues(alpha: 0.15)
                            : AppTheme.glassWhite(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSpeaking
                              ? AppColors.accent.withValues(alpha: 0.5)
                              : AppTheme.glassBorder(context),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSpeaking
                                ? Icons.stop_rounded
                                : Icons.volume_up_rounded,
                            color: isSpeaking
                                ? AppColors.accent
                                : AppTheme.textMuted(context),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isSpeaking ? 'Stop' : 'Listen',
                            style: TextStyle(
                              color: isSpeaking
                                  ? AppColors.accent
                                  : AppTheme.textMuted(context),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ── Quick chip ────────────────────────────────
  Widget _quickChip(BuildContext context, String text) {
    final textPrimary = AppTheme.textPrimary(context);
    final glassWhite  = AppTheme.glassWhite(context);
    final glassBorder = AppTheme.glassBorder(context);

    return GestureDetector(
      onTap: () {
        controller.text = text
            .replaceAll('📊 ', '')
            .replaceAll('🔴 ', '')
            .replaceAll('📋 ', '')
            .replaceAll('🖥️ ', '')
            .replaceAll('🔧 ', '');
        sendMessage();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: glassWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: glassBorder),
        ),
        child: Text(text,
            style: TextStyle(color: textPrimary, fontSize: 12)),
      ),
    );
  }
}
