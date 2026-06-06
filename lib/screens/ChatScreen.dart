import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../widgets/ImageGalleryViewer.dart';
import '../services/supabase_service.dart';
import '../providers/ChatProvider.dart';
import '../providers/RelationshipProvider.dart';
import '../providers/AuthProvider.dart';
import '../providers/SecurityProvider.dart';
import 'SettingsScreen.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  String? _replyToId;
  Map<String, dynamic>? _replyingToMessage;
  bool _isSending = false;
  List<PlatformFile> _selectedImages = [];
  bool _showScrollToBottom = false;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final relation = Provider.of<RelationshipProvider>(
        context,
        listen: false,
      );
      if (relation.conversation != null) {
        final partnerPubKey = relation.partner?['public_key'];
        Provider.of<ChatProvider>(
          context,
          listen: false,
        ).setConversationId(relation.conversation!['id'], partnerPubKey);
      }
    });
  }

  void _scrollListener() {
    if (_scrollController.position.pixels > 200) {
      if (!_showScrollToBottom) setState(() => _showScrollToBottom = true);
    } else {
      if (_showScrollToBottom) setState(() => _showScrollToBottom = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildImageGrid(List<String> images, ThemeData theme, bool isPending) {
    Widget buildImage(String url) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isPending) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ImageGalleryViewer(imagePath: url, isNetwork: true),
              ),
            );
          },
          child: Hero(
            tag: url,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: isPending
                  ? Image.file(File(url), fit: BoxFit.cover)
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: theme.colorScheme.surface,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      );
    }

    if (images.isEmpty) return const SizedBox.shrink();
    if (images.length == 1) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: SizedBox(width: 200, child: buildImage(images.first)),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: SizedBox(
        width: 240,
        child: GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) {
            return buildImage(images[index]);
          },
        ),
      ),
    );
  }

  Future<void> _pickImages() async {
    try {
      Provider.of<SecurityProvider>(context, listen: false).ignoreNextLock();
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'],
        allowMultiple: true,
      );

      if (result != null) {
        setState(() {
          // Limit to 10 images
          _selectedImages.addAll(result.files);
          if (_selectedImages.length > 10) {
            _selectedImages = _selectedImages.sublist(0, 10);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Maximum 10 images allowed')),
            );
          }
        });
      }
    } catch (e) {
      print('Error picking images: $e');
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if ((text.isEmpty && _selectedImages.isEmpty) || _isSending) return;

    final chat = Provider.of<ChatProvider>(context, listen: false);
    _messageController.clear();
    final imagesToSend = List<PlatformFile>.from(_selectedImages);

    setState(() {
      _isSending = true;
      _selectedImages.clear();
    });

    await chat.sendMessage(
      text,
      imageFiles: imagesToSend.isNotEmpty ? imagesToSend : null,
      replyToId: _replyToId,
    );

    if (mounted) {
      setState(() {
        _replyToId = null;
        _replyingToMessage = null;
        _isSending = false;
      });
      _scrollToBottom();
    }
  }

  void _showContextBottomSheet(Map<String, dynamic> msg) {
    final theme = Theme.of(context);
    final chat = Provider.of<ChatProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isMe = msg['sender_id'] == auth.user?.id;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.0)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Reaction Picker
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 12.0,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['❤️', '😂', '😮', '😢', '👍', '👎'].map((emoji) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          chat.toggleReaction(msg['id'], emoji);
                        },
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 32),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _replyToId = msg['id'];
                    _replyingToMessage = msg;
                  });
                },
              ),
              if (isMe) ...[
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit Message'),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditDialog(msg);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete, color: theme.colorScheme.error),
                  title: Text(
                    'Delete Message',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    chat.deleteMessage(msg['id']);
                  },
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showEditDialog(Map<String, dynamic> msg) {
    String messageText = '';
    List<String> messageImages = [];
    try {
      final Map<String, dynamic> parsed = jsonDecode(
        msg['encrypted_payload'] ?? '',
      );
      messageText = parsed['t'] ?? '';
      if (parsed['i'] != null) {
        messageImages = List<String>.from(parsed['i']);
      }
    } catch (_) {
      messageText = msg['encrypted_payload'] ?? '';
    }

    final controller = TextEditingController(text: messageText);
    final chat = Provider.of<ChatProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              chat.editMessage(
                msg['id'],
                controller.text,
                images: messageImages.isNotEmpty ? messageImages : null,
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildReactions(Map<String, dynamic> msg, bool isMe, ThemeData theme) {
    if (msg['encrypted_reactions'] == null) return const SizedBox.shrink();
    Map<String, dynamic> reactions = {};
    try {
      reactions = jsonDecode(msg['encrypted_reactions']);
    } catch (_) {
      return const SizedBox.shrink();
    }

    if (reactions.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(
          top: 2.0,
          bottom: 4.0,
          right: 12.0,
          left: 12.0,
        ),
        child: Wrap(
          spacing: 4.0,
          children: reactions.entries.map((e) {
            final emoji = e.key;
            final count = (e.value as List).length;
            if (count == 0) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6.0,
                vertical: 2.0,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 12)),
                  if (count > 1) ...[
                    const SizedBox(width: 4),
                    Text(
                      '$count',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    String partnerName,
    ThemeData theme,
    String? partnerImage,
  ) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.history,
                      size: 16,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'History is on',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Messages sent with the history turned on are saved',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onBackground.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportChatToPdf(
    BuildContext context,
    ChatProvider chat,
    String partnerName,
  ) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: const [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Generating PDF...'),
          ],
        ),
      ),
    );

    try {
      final pdf = pw.Document();

      final emoji = await PdfGoogleFonts.notoColorEmoji();
      final baseFont = await PdfGoogleFonts.robotoRegular();
      final boldFont = await PdfGoogleFonts.robotoBold();
      final theme = pw.ThemeData.withFont(
        base: baseFont,
        bold: boldFont,
        fontFallback: [emoji],
      );

      final List<pw.Widget> messageWidgets = [];
      final currentUserId = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).profile?['id'];

      for (var msg in chat.messages) {
        final isMe = msg['sender_id'] == currentUserId;
        final sender = isMe ? 'You' : partnerName;

        String text = '';
        List<String> images = [];
        try {
          final Map<String, dynamic> parsed = jsonDecode(
            msg['encrypted_payload'] ?? '',
          );
          text = parsed['t'] ?? '';
          if (parsed['i'] != null) {
            images = List<String>.from(parsed['i']);
          }
        } catch (_) {
          text = msg['encrypted_payload'] ?? '';
        }

        if (text.isEmpty && images.isEmpty) continue;

        DateTime? createdAt;
        if (msg['created_at'] != null) {
          createdAt = DateTime.tryParse(msg['created_at'])?.toLocal();
        }
        String timeStr = createdAt != null
            ? DateFormat.jm().format(createdAt)
            : '';

        final List<pw.Widget> imageWidgets = [];
        for (String url in images) {
          try {
            final response = await http.get(Uri.parse(url));
            if (response.statusCode == 200) {
              final memoryImage = pw.MemoryImage(response.bodyBytes);
              imageWidgets.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 8),
                  width: 150,
                  height: 150,
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(8),
                    image: pw.DecorationImage(
                      image: memoryImage,
                      fit: pw.BoxFit.cover,
                    ),
                  ),
                ),
              );
            }
          } catch (e) {
            debugPrint('Failed to load image for PDF: $e');
          }
        }

        messageWidgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            alignment: isMe
                ? pw.Alignment.centerRight
                : pw.Alignment.centerLeft,
            child: pw.Container(
              constraints: const pw.BoxConstraints(maxWidth: 350),
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: pw.BoxDecoration(
                color: isMe
                    ? PdfColor.fromHex('#E1F5FE')
                    : PdfColor.fromHex('#F5F5F5'),
                borderRadius: pw.BorderRadius.only(
                  topLeft: const pw.Radius.circular(16),
                  topRight: const pw.Radius.circular(16),
                  bottomLeft: pw.Radius.circular(isMe ? 16 : 4),
                  bottomRight: pw.Radius.circular(isMe ? 4 : 16),
                ),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: isMe
                    ? pw.CrossAxisAlignment.end
                    : pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    sender,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                      color: PdfColor.fromHex('#757575'),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  if (text.isNotEmpty)
                    pw.Text(
                      text,
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.black,
                      ),
                    ),
                  ...imageWidgets,
                  if (timeStr.isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    pw.Text(
                      timeStr,
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColor.fromHex('#9E9E9E'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }

      if (messageWidgets.isEmpty) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No messages to export')));
        return;
      }

      pdf.addPage(
        pw.MultiPage(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 20),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#FF4081'),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'Chat History with $partnerName',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          build: (pw.Context context) {
            return messageWidgets;
          },
        ),
      );

      // Save to Downloads directory
      Directory? downloadsDir;
      try {
        downloadsDir = await getDownloadsDirectory();
      } catch (_) {}

      String savePath;
      if (Platform.isAndroid) {
        savePath = '/storage/emulated/0/Download/chat_history_$partnerName.pdf';
      } else {
        savePath =
            '${downloadsDir?.path ?? (await getApplicationDocumentsDirectory()).path}/chat_history_$partnerName.pdf';
      }

      final file = File(savePath);
      await file.writeAsBytes(await pdf.save());

      Navigator.pop(context); // Close dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Chat saved to Downloads: chat_history_$partnerName.pdf',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final relation = Provider.of<RelationshipProvider>(context);
    final chat = Provider.of<ChatProvider>(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Auto-scroll to bottom when messages load or a new message arrives
    if (chat.messages.length != _lastMessageCount) {
      _lastMessageCount = chat.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          // Add a tiny delay to ensure images/layout have fully rendered their heights
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && _scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          });
        }
      });
    }

    final partnerName =
        relation.partner?['name'] ?? relation.partner?['username'] ?? 'Partner';

    bool partnerOnline = relation.partner?['online_status'] == true;
    if (partnerOnline && relation.partner?['last_seen'] != null) {
      try {
        final lastSeen = DateTime.parse(relation.partner!['last_seen']).toUtc();
        if (DateTime.now().toUtc().difference(lastSeen).inSeconds > 45) {
          partnerOnline = false;
        }
      } catch (_) {}
    }
    final partnerPubKey = relation.partner?['public_key'];
    final partnerImage = relation.partner?['profile_image'];

    if (partnerPubKey != null &&
        chat.sharedSecret == null &&
        relation.conversation != null) {
      Future.microtask(() {
        chat.initializeSharedSecret(partnerPubKey);
      });
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      floatingActionButton: null,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.background.withOpacity(0.5),
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(color: Colors.transparent),
          ),
        ),
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: InkWell(
          onTap: () =>
              _showPartnerProfileBottomSheet(context, relation.partner, theme),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: Row(
              children: [
                Hero(
                  tag: 'partner_avatar_hero',
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        backgroundImage: partnerImage != null
                            ? CachedNetworkImageProvider(partnerImage)
                            : null,
                        child: partnerImage == null
                            ? Text(
                                partnerName.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      if (partnerOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.background,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              partnerName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onBackground,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (relation.partner?['is_verified'] == true) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.verified,
                              color: theme.colorScheme.primary,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        partnerOnline ? 'Online' : 'Offline',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: partnerOnline
                              ? Colors.green
                              : theme.colorScheme.onBackground.withOpacity(0.6),
                          fontSize: 12,
                          fontWeight: partnerOnline
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.phone_outlined,
              color: theme.colorScheme.onBackground,
            ),
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Coming soon')));
            },
          ),
          IconButton(
            icon: Icon(
              Icons.videocam_outlined,
              color: theme.colorScheme.onBackground,
            ),
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Coming soon')));
            },
          ),
          PopupMenuButton<int>(
            icon: Icon(Icons.more_vert, color: theme.colorScheme.onBackground),
            onSelected: (value) {
              if (value == 0) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Chat History'),
                    content: const Text(
                      'Are you sure you want to delete all messages? This action cannot be undone and will delete the history for both you and your partner.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Provider.of<ChatProvider>(
                            context,
                            listen: false,
                          ).clearChatHistory();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Chat history deleted'),
                            ),
                          );
                        },
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              } else if (value == 1) {
                _exportChatToPdf(context, chat, partnerName);
              } else if (value == 2) {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const SettingsScreen(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: Tween<double>(
                                begin: 0.9,
                                end: 1.0,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 0,
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text('Delete Chat History'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 1,
                child: Row(
                  children: [
                    Icon(
                      Icons.picture_as_pdf_outlined,
                      color: Colors.orange,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text('Export Chat (PDF)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 2,
                child: Row(
                  children: [
                    Icon(
                      Icons.settings_outlined,
                      color: Colors.blueAccent,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text('Settings'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: Image.asset(
                'assets/chat_bg.png',
                repeat: ImageRepeat.repeat,
              ),
            ),
          ),
          Column(
            children: [
              // Chat Area
              Expanded(
                child: chat.loading
                    ? const Center(child: CircularProgressIndicator())
                    : chat.messages.isEmpty
                    ? _buildEmptyState(partnerName, theme, partnerImage)
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        cacheExtent: 2000,
                        padding: const EdgeInsets.fromLTRB(
                          16.0,
                          110.0,
                          16.0,
                          12.0,
                        ),
                        itemCount:
                            chat.messages.length +
                            (chat.isPartnerTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == chat.messages.length) {
                            return TypingIndicator(partnerName: partnerName);
                          }
                          final msg = chat.messages[index];
                          final isMe = msg['sender_id'] == auth.user?.id;
                          final isEdited = msg['is_edited'] == true;

                          // Extract and format time
                          String timeStr = '';
                          String currentDateStr = '';
                          String prevDateStr = '';
                          try {
                            final dateStr = msg['sent_at'] ?? msg['created_at'];
                            if (dateStr != null) {
                              final parsedDate = DateTime.parse(
                                dateStr,
                              ).toLocal();
                              timeStr = DateFormat(
                                'hh:mm a',
                              ).format(parsedDate);

                              final now = DateTime.now();
                              final todayUtc = DateTime.utc(
                                now.year,
                                now.month,
                                now.day,
                              );
                              final msgDateUtc = DateTime.utc(
                                parsedDate.year,
                                parsedDate.month,
                                parsedDate.day,
                              );
                              final diff = todayUtc
                                  .difference(msgDateUtc)
                                  .inDays;

                              if (diff == 0) {
                                currentDateStr = 'Today';
                              } else if (diff == 1) {
                                currentDateStr = 'Yesterday';
                              } else {
                                currentDateStr = DateFormat(
                                  'MMM d, yyyy',
                                ).format(parsedDate);
                              }
                            }
                            if (index > 0) {
                              final prevDateStrRaw =
                                  chat.messages[index - 1]['sent_at'] ??
                                  chat.messages[index - 1]['created_at'];
                              if (prevDateStrRaw != null) {
                                final prevDate = DateTime.parse(
                                  prevDateStrRaw,
                                ).toLocal();
                                final now = DateTime.now();
                                final todayUtc = DateTime.utc(
                                  now.year,
                                  now.month,
                                  now.day,
                                );
                                final prevMsgDateUtc = DateTime.utc(
                                  prevDate.year,
                                  prevDate.month,
                                  prevDate.day,
                                );
                                final diff = todayUtc
                                    .difference(prevMsgDateUtc)
                                    .inDays;

                                if (diff == 0) {
                                  prevDateStr = 'Today';
                                } else if (diff == 1) {
                                  prevDateStr = 'Yesterday';
                                } else {
                                  prevDateStr = DateFormat(
                                    'MMM d, yyyy',
                                  ).format(prevDate);
                                }
                              }
                            }
                          } catch (_) {}

                          bool showDateHeader =
                              index == 0 || currentDateStr != prevDateStr;

                          return Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              if (showDateHeader &&
                                  currentDateStr.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.center,
                                  child: Text(
                                    currentDateStr,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: theme.colorScheme.onBackground
                                              .withOpacity(0.7),
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutBack,
                                tween: Tween(begin: 0.8, end: 1.0),
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: value,
                                    alignment: isMe
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: child,
                                  );
                                },
                                child: Dismissible(
                                  key: Key(
                                    msg['id'].toString() + '_dismissible',
                                  ),
                                  direction: DismissDirection.startToEnd,
                                  confirmDismiss: (direction) async {
                                    setState(() {
                                      _replyToId = msg['id'];
                                      _replyingToMessage = msg;
                                    });
                                    return false;
                                  },
                                  background: Container(
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.only(left: 16.0),
                                    color: Colors.transparent,
                                    child: Icon(
                                      Icons.reply,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onLongPress: () =>
                                          _showContextBottomSheet(msg),
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(20.0),
                                        topRight: const Radius.circular(20.0),
                                        bottomLeft: Radius.circular(
                                          isMe ? 20.0 : 4.0,
                                        ),
                                        bottomRight: Radius.circular(
                                          isMe ? 4.0 : 20.0,
                                        ),
                                      ),
                                      child: Align(
                                        alignment: isMe
                                            ? Alignment.centerRight
                                            : Alignment.centerLeft,
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 4.0,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 18.0,
                                            vertical: 12.0,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isMe
                                                ? theme
                                                      .colorScheme
                                                      .primaryContainer
                                                : theme
                                                      .colorScheme
                                                      .surfaceVariant,
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(
                                                20.0,
                                              ),
                                              topRight: const Radius.circular(
                                                20.0,
                                              ),
                                              bottomLeft: Radius.circular(
                                                isMe ? 20.0 : 4.0,
                                              ),
                                              bottomRight: Radius.circular(
                                                isMe ? 4.0 : 20.0,
                                              ),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: isMe
                                                ? CrossAxisAlignment.end
                                                : CrossAxisAlignment.start,
                                            children: [
                                              Builder(
                                                builder: (context) {
                                                  String messageText = '';
                                                  List<String> messageImages =
                                                      [];
                                                  try {
                                                    final Map<String, dynamic>
                                                    parsed = jsonDecode(
                                                      msg['encrypted_payload'] ??
                                                          '',
                                                    );
                                                    messageText =
                                                        parsed['t'] ?? '';
                                                    if (parsed['i'] != null) {
                                                      messageImages =
                                                          List<String>.from(
                                                            parsed['i'],
                                                          );
                                                    }
                                                  } catch (_) {
                                                    messageText =
                                                        msg['encrypted_payload'] ??
                                                        '';
                                                  }

                                                  // Process replied message if exists
                                                  Map<String, dynamic>?
                                                  repliedMsg;
                                                  final replyId =
                                                      msg['parent_message_id'] ??
                                                      msg['reply_to'];
                                                  if (replyId != null) {
                                                    try {
                                                      repliedMsg = chat.messages
                                                          .firstWhere(
                                                            (m) =>
                                                                m['id'] ==
                                                                replyId,
                                                          );
                                                    } catch (_) {}
                                                  }
                                                  String repliedText = '';
                                                  if (repliedMsg != null) {
                                                    try {
                                                      final Map<String, dynamic>
                                                      rParsed = jsonDecode(
                                                        repliedMsg['encrypted_payload'] ??
                                                            '',
                                                      );
                                                      repliedText =
                                                          rParsed['t'] ?? '';
                                                    } catch (_) {
                                                      repliedText =
                                                          repliedMsg['encrypted_payload'] ??
                                                          '';
                                                    }
                                                  }

                                                  return Column(
                                                    crossAxisAlignment: isMe
                                                        ? CrossAxisAlignment.end
                                                        : CrossAxisAlignment
                                                              .start,
                                                    children: [
                                                      if (repliedText
                                                          .isNotEmpty)
                                                        Container(
                                                          margin:
                                                              const EdgeInsets.only(
                                                                bottom: 8.0,
                                                              ),
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal:
                                                                    10.0,
                                                                vertical: 6.0,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color:
                                                                (isMe
                                                                        ? theme
                                                                              .colorScheme
                                                                              .onPrimaryContainer
                                                                        : theme
                                                                              .colorScheme
                                                                              .onSurfaceVariant)
                                                                    .withOpacity(
                                                                      0.1,
                                                                    ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8.0,
                                                                ),
                                                            border: Border(
                                                              left: BorderSide(
                                                                color: isMe
                                                                    ? theme
                                                                          .colorScheme
                                                                          .onPrimaryContainer
                                                                    : theme
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                width: 3,
                                                              ),
                                                            ),
                                                          ),
                                                          child: Text(
                                                            repliedText,
                                                            maxLines: 2,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              color:
                                                                  (isMe
                                                                          ? theme.colorScheme.onPrimaryContainer
                                                                          : theme.colorScheme.onSurfaceVariant)
                                                                      .withOpacity(
                                                                        0.8,
                                                                      ),
                                                            ),
                                                          ),
                                                        ),
                                                      if (messageImages
                                                          .isNotEmpty)
                                                        _buildImageGrid(
                                                          messageImages,
                                                          theme,
                                                          msg['is_pending'] ==
                                                              true,
                                                        ),
                                                      if (messageText
                                                          .isNotEmpty)
                                                        Text(
                                                          messageText,
                                                          style: TextStyle(
                                                            color: isMe
                                                                ? theme
                                                                      .colorScheme
                                                                      .onPrimaryContainer
                                                                : theme
                                                                      .colorScheme
                                                                      .onSurfaceVariant,
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                    ],
                                                  );
                                                },
                                              ),
                                              if (isEdited) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  'edited',
                                                  style: theme.textTheme.labelSmall?.copyWith(
                                                    fontSize: 9,
                                                    color:
                                                        (isMe
                                                                ? theme
                                                                      .colorScheme
                                                                      .onPrimaryContainer
                                                                : theme
                                                                      .colorScheme
                                                                      .onSurfaceVariant)
                                                            .withOpacity(0.6),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              _buildReactions(msg, isMe, theme),
                              if (timeStr.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 2.0,
                                    bottom: 4.0,
                                    right: 8.0,
                                    left: 8.0,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        timeStr,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontSize: 10,
                                              color: theme
                                                  .colorScheme
                                                  .onBackground
                                                  .withOpacity(0.6),
                                            ),
                                      ),
                                      if (isMe) ...[
                                        const SizedBox(width: 4),
                                        if (msg['is_pending'] == true)
                                          Icon(
                                            Icons.access_time,
                                            size: 12,
                                            color: theme
                                                .colorScheme
                                                .onBackground
                                                .withOpacity(0.6),
                                          )
                                        else if (msg['status'] == 'read')
                                          Icon(
                                            Icons.done_all,
                                            size: 14,
                                            color: theme.colorScheme.primary,
                                          )
                                        else if (msg['status'] == 'delivered')
                                          Icon(
                                            Icons.done_all,
                                            size: 14,
                                            color: theme
                                                .colorScheme
                                                .onBackground
                                                .withOpacity(0.6),
                                          )
                                        else
                                          Icon(
                                            Icons.check,
                                            size: 14,
                                            color: theme
                                                .colorScheme
                                                .onBackground
                                                .withOpacity(0.6),
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
              ),
              // Reply preview
              if (_replyingToMessage != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  color: theme.colorScheme.surfaceVariant,
                  child: Row(
                    children: [
                      Icon(
                        Icons.reply,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            String previewText = '';
                            try {
                              final Map<String, dynamic> parsed = jsonDecode(
                                _replyingToMessage!['encrypted_payload'] ?? '',
                              );
                              previewText = parsed['t'] ?? '';
                            } catch (_) {
                              previewText =
                                  _replyingToMessage!['encrypted_payload'] ??
                                  '';
                            }
                            return Text(
                              'Replying to: $previewText',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            );
                          },
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _replyToId = null;
                            _replyingToMessage = null;
                          });
                        },
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              // Selected Images Preview Row
              if (_selectedImages.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        final file = _selectedImages[index];
                        return Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(
                                right: 8.0,
                                top: 8.0,
                              ),
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8.0),
                                image: file.path != null
                                    ? DecorationImage(
                                        image: FileImage(File(file.path!)),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                color: theme.colorScheme.surfaceVariant,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedImages.removeAt(index);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    size: 12,
                                    color: theme.colorScheme.surface,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              // MUI Bottom Input Row
              Padding(
                padding: const EdgeInsets.only(
                  left: 12.0,
                  right: 12.0,
                  bottom: 20.0,
                  top: 4.0,
                ),
                child: Row(
                  children: [
                    // Pill Input field with image icon
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20.0),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceVariant
                                  .withOpacity(0.5),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _messageController,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 15,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Message...',
                                      hintStyle: TextStyle(
                                        color: theme
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withOpacity(0.6),
                                        fontSize: 15,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 10.0,
                                          ),
                                      isDense: true,
                                    ),
                                    onChanged: (text) {
                                      Provider.of<ChatProvider>(
                                        context,
                                        listen: false,
                                      ).handleUserTyping();
                                    },
                                    onSubmitted: (_) => _sendMessage(),
                                  ),
                                ),
                                Material(
                                  type: MaterialType.transparency,
                                  shape: const CircleBorder(),
                                  clipBehavior: Clip.hardEdge,
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.image_outlined,
                                      color: theme.colorScheme.primary,
                                      size: 20,
                                    ),
                                    onPressed: _pickImages,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                    splashRadius: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedBuilder(
                      animation: _messageController,
                      builder: (context, _) {
                        bool canSend =
                            _messageController.text.trim().isNotEmpty ||
                            _selectedImages.isNotEmpty;
                        return Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.hardEdge,
                          child: InkWell(
                            onTap: canSend ? _sendMessage : null,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: canSend
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.surfaceVariant,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: _isSending
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: canSend
                                              ? theme.colorScheme.onPrimary
                                              : theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                          strokeWidth: 2.0,
                                        ),
                                      )
                                    : Padding(
                                        padding: const EdgeInsets.only(
                                          left: 3.0,
                                        ),
                                        child: Icon(
                                          Icons.send,
                                          color: canSend
                                              ? theme.colorScheme.onPrimary
                                              : theme
                                                    .colorScheme
                                                    .onSurfaceVariant
                                                    .withOpacity(0.5),
                                          size: 18,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        );
                      },
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

  void _showPartnerProfileBottomSheet(
    BuildContext context,
    Map<String, dynamic>? partner,
    ThemeData theme,
  ) {
    if (partner == null) return;

    final name = partner['name'] ?? 'Unknown Name';
    final username = partner['username'] ?? 'unknown';
    final gender = partner['gender'] ?? 'Not specified';
    final profileImage = partner['profile_image'];
    final isVerified = partner['is_verified'] == true;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Hero(
                tag: 'partner_avatar_hero',
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.hardEdge,
                  child: InkWell(
                    onLongPress: () {
                      if (profileImage != null) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              backgroundColor: Colors.black,
                              appBar: AppBar(
                                backgroundColor: Colors.black,
                                iconTheme: const IconThemeData(
                                  color: Colors.white,
                                ),
                              ),
                              body: Center(
                                child: InteractiveViewer(
                                  child: CachedNetworkImage(
                                    imageUrl: profileImage,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                    },
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      backgroundImage: profileImage != null
                          ? CachedNetworkImageProvider(profileImage)
                          : null,
                      child: profileImage == null
                          ? Text(
                              name.isNotEmpty
                                  ? name.substring(0, 1).toUpperCase()
                                  : 'U',
                              style: TextStyle(
                                fontSize: 28,
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified,
                            color: theme.colorScheme.primary,
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@$username',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            gender,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class TypingIndicator extends StatefulWidget {
  final String partnerName;
  const TypingIndicator({super.key, required this.partnerName});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
    });

    _animations = _controllers.map((controller) {
      return Tween<double>(
        begin: 0,
        end: -8,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    }).toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14.0,
              vertical: 10.0,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16.0),
                topRight: Radius.circular(16.0),
                bottomLeft: Radius.circular(4.0),
                bottomRight: Radius.circular(16.0),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.partnerName} is typing',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: List.generate(3, (index) {
                    return AnimatedBuilder(
                      animation: _animations[index],
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _animations[index].value),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2.0,
                            ),
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FloatingHeartsBackground extends StatefulWidget {
  const FloatingHeartsBackground({super.key});
  @override
  State<FloatingHeartsBackground> createState() =>
      _FloatingHeartsBackgroundState();
}

class _Heart {
  double x;
  double y;
  double speed;
  double size;
  double opacity;

  _Heart(this.x, this.y, this.speed, this.size, this.opacity);
}

class _FloatingHeartsBackgroundState extends State<FloatingHeartsBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Heart> _hearts = [];
  final Random _rnd = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _controller.addListener(() {
      if (!mounted) return;
      for (var heart in _hearts) {
        heart.y -= heart.speed;
        if (heart.y < -50) {
          heart.y = MediaQuery.of(context).size.height + 50;
          heart.x = _rnd.nextDouble() * MediaQuery.of(context).size.width;
        }
      }
      setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hearts.isEmpty) {
      final width = MediaQuery.of(context).size.width;
      final height = MediaQuery.of(context).size.height;
      for (int i = 0; i < 20; i++) {
        _hearts.add(
          _Heart(
            _rnd.nextDouble() * width,
            _rnd.nextDouble() * height,
            0.3 + _rnd.nextDouble() * 1.5,
            10.0 + _rnd.nextDouble() * 25.0,
            0.02 + _rnd.nextDouble() * 0.08,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomPaint(
      painter: _HeartsPainter(_hearts, theme.colorScheme.primary),
      child: Container(),
    );
  }
}

class _HeartsPainter extends CustomPainter {
  final List<_Heart> hearts;
  final Color color;

  _HeartsPainter(this.hearts, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    for (var heart in hearts) {
      final paint = Paint()..color = color.withOpacity(heart.opacity);
      _drawHeart(canvas, paint, Offset(heart.x, heart.y), heart.size);
    }
  }

  void _drawHeart(Canvas canvas, Paint paint, Offset center, double size) {
    final path = Path();
    path.moveTo(center.dx, center.dy + size / 4);
    path.cubicTo(
      center.dx - size / 2,
      center.dy - size / 2,
      center.dx - size,
      center.dy + size / 3,
      center.dx,
      center.dy + size,
    );
    path.cubicTo(
      center.dx + size,
      center.dy + size / 3,
      center.dx + size / 2,
      center.dy - size / 2,
      center.dx,
      center.dy + size / 4,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
