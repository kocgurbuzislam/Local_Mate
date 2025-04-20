import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:yerel_rehber_app/colors.dart';
import 'package:yerel_rehber_app/ui/views/guide_detail_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String guideId;
  final String guideName;

  const ChatScreen({
    Key? key,
    required this.chatId,
    required this.guideId,
    required this.guideName,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserProfileImage;

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _loadMessages();
  }

  Future<void> _initializeUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      setState(() {
        _currentUserId = currentUser.uid;
      });

      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _currentUserName = userData['name'] ?? 'İsimsiz Kullanıcı';
            _currentUserProfileImage = userData['profileImage'];
          });
        }
      } catch (e) {
        print('Kullanıcı bilgileri alınırken hata: $e');
      }
    }
  }

  Future<void> _loadMessages() async {
    try {
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        _messages = messagesSnapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList();
        _isLoading = false;
      });

      if (_messages.isNotEmpty) {
        _scrollToBottom();
      }
    } catch (e) {
      print('Mesajlar yüklenirken hata: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _currentUserId == null)
      return;

    try {
      final messageData = {
        'senderId': _currentUserId,
        'text': _messageController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'senderName': _currentUserName,
        'senderProfileImage': _currentUserProfileImage,
      };

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add(messageData);

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .set({
        'lastMessage': messageData['text'],
        'lastMessageTime': messageData['timestamp'],
        'participants': [_currentUserId, widget.guideId],
        'users': [_currentUserId, widget.guideId], // Eski sürüm uyumluluğu için
      }, SetOptions(merge: true));

      _messageController.clear();
      _loadMessages();
    } catch (e) {
      print('Mesaj gönderilirken hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesaj gönderilemedi. Lütfen tekrar deneyin.')),
      );
    }
  }

  Future<void> _shareLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Konum izni reddedildi')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Konum izinlerini ayarlardan etkinleştirin'),
          ),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      String locationMessage =
          'Konum: ${position.latitude},${position.longitude}';

      if (_currentUserId == null) return;

      try {
        final messageData = {
          'senderId': _currentUserId,
          'text': locationMessage,
          'timestamp': FieldValue.serverTimestamp(),
          'senderName': _currentUserName,
          'senderProfileImage': _currentUserProfileImage,
          'type': 'location',
          'latitude': position.latitude,
          'longitude': position.longitude,
        };

        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .collection('messages')
            .add(messageData);

        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .set({
          'lastMessage': 'Konum paylaşıldı',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'participants': [_currentUserId, widget.guideId],
          'users': [
            _currentUserId,
            widget.guideId
          ], // Eski sürüm uyumluluğu için
        }, SetOptions(merge: true));

        _loadMessages();
      } catch (e) {
        print('Konum mesajı gönderilirken hata: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Konum paylaşılamadı. Lütfen tekrar deneyin.')),
        );
      }
    } catch (e) {
      print('Konum alınamadı: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Konum alınamadı: $e')),
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: mainColor),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: mainColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.guideName.isNotEmpty
                      ? widget.guideName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: mainColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.guideName,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Çevrimiçi',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: mainColor),
            onPressed: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      GuideDetailScreen(
                    guideData: {
                      'userId': widget.guideId,
                      'fullName': widget.guideName,
                    },
                    guideId: widget.guideId,
                  ),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    var begin = const Offset(1.0, 0.0);
                    var end = Offset.zero;
                    var curve = Curves.ease;
                    var tween = Tween(begin: begin, end: end)
                        .chain(CurveTween(curve: curve));
                    return SlideTransition(
                      position: animation.drive(tween),
                      child: child,
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          image: const DecorationImage(
            image: AssetImage('assets/images/chat_bg.png'),
            fit: BoxFit.cover,
            opacity: 0.05,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Henüz mesaj yok.\nİlk mesajı siz gönderin!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isMe = message['senderId'] == _currentUserId;
                            return Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75,
                                ),
                                margin: EdgeInsets.only(
                                  top: 4,
                                  bottom: 4,
                                  left: isMe ? 48 : 0,
                                  right: isMe ? 0 : 48,
                                ),
                                child: _buildMessageBubble(message, isMe),
                              ),
                            );
                          },
                        ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: IconButton(
                        icon:
                            Icon(Icons.location_on, color: mainColor, size: 24),
                        onPressed: _shareLocation,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Mesajınızı yazın...',
                            hintStyle: TextStyle(color: Colors.grey[500]),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: mainColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white, size: 24),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe) {
    if (message['type'] == 'location') {
      return Container(
        decoration: BoxDecoration(
          color: isMe ? mainColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () async {
              final coordinates = message['text'].split(': ')[1];
              final parts = coordinates.split(',');
              final lat = parts[0];
              final lng = parts[1];

              final Uri mapsUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');

              try {
                if (!await launchUrl(mapsUri)) {
                  final Uri webUri =
                      Uri.parse('https://www.google.com/maps?q=$lat,$lng');
                  if (!await launchUrl(webUri,
                      mode: LaunchMode.externalApplication)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Harita uygulaması bulunamadı')),
                    );
                  }
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Harita açılırken bir hata oluştu: $e')),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on,
                    color: isMe ? Colors.white : mainColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Konum',
                    style: TextStyle(
                      fontSize: 15,
                      color: isMe ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isMe ? mainColor : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isMe ? 20 : 5),
          bottomRight: Radius.circular(isMe ? 5 : 20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                message['senderName'] ?? 'İsimsiz',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          Text(
            message['text'],
            style: TextStyle(
              color: isMe ? Colors.white : Colors.black87,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              message['timestamp'] != null
                  ? DateFormat('HH:mm')
                      .format((message['timestamp'] as Timestamp).toDate())
                  : '',
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.white.withOpacity(0.7) : Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
