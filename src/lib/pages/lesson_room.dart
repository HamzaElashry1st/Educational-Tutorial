import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_background/flutter_background.dart';
import '../main.dart';

class Helper {
  static Future<void> switchCamera(MediaStreamTrack track) async {
    if (track.kind == 'video') {
      await track.switchCamera();
    }
  }
}

class Stroke {
  final String id;
  final List<Map<String, dynamic>> points;
  final double width;
  final String color;
  final bool isEraser;
  final String creatorId;
  Stroke({
    required this.id,
    required this.points,
    required this.width,
    required this.color,
    required this.isEraser,
    required this.creatorId,
  });
  Map<String, dynamic> toMap() => {
    'id': id,
    'points': points,
    'width': width,
    'color': color,
    'isEraser': isEraser,
    'creatorId': creatorId,
  };
  factory Stroke.fromMap(Map<String, dynamic> m) => Stroke(
    id: m['id'] ?? const Uuid().v4(),
    points: List<Map<String, dynamic>>.from(m['points'] ?? []),
    width: (m['width'] ?? 4).toDouble(),
    color: m['color'] ?? '0xFF000000',
    isEraser: m['isEraser'] ?? false,
    creatorId: m['creatorId'] ?? '',
  );
}

class WhiteboardText {
  final String id;
  final String text;
  final double x;
  final double y;
  final bool bold;
  final double fontSize;
  final double rotation;
  final double scale;
  final String color;
  final String creatorId;
  WhiteboardText({
    required this.id,
    required this.text,
    required this.x,
    required this.y,
    required this.bold,
    required this.fontSize,
    this.rotation = 0,
    this.scale = 1.0,
    this.color = '0xFF000000',
    required this.creatorId,
  });
  Map<String, dynamic> toMap() => {
    'id': id,
    'text': text,
    'x': x,
    'y': y,
    'bold': bold,
    'fontSize': fontSize,
    'rotation': rotation,
    'scale': scale,
    'color': color,
    'creatorId': creatorId,
  };
  factory WhiteboardText.fromMap(Map<String, dynamic> m) => WhiteboardText(
    id: m['id'] ?? const Uuid().v4(),
    text: m['text'] ?? '',
    x: (m['x'] ?? 0).toDouble(),
    y: (m['y'] ?? 0).toDouble(),
    bold: m['bold'] ?? false,
    fontSize: (m['fontSize'] ?? 18).toDouble(),
    rotation: (m['rotation'] ?? 0).toDouble(),
    scale: (m['scale'] ?? 1.0).toDouble(),
    color: m['color'] ?? '0xFF000000',
    creatorId: m['creatorId'] ?? '',
  );
}

class Line {
  final String id;
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final double width;
  final String color;
  final List<double>? dashPattern;
  final String creatorId;
  Line({
    required this.id,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.width,
    required this.color,
    this.dashPattern,
    required this.creatorId,
  });
  Map<String, dynamic> toMap() => {
    'id': id,
    'startX': startX,
    'startY': startY,
    'endX': endX,
    'endY': endY,
    'width': width,
    'color': color,
    'dashPattern': dashPattern,
    'creatorId': creatorId,
  };
  factory Line.fromMap(Map<String, dynamic> m) => Line(
    id: m['id'] ?? const Uuid().v4(),
    startX: (m['startX'] ?? 0).toDouble(),
    startY: (m['startY'] ?? 0).toDouble(),
    endX: (m['endX'] ?? 0).toDouble(),
    endY: (m['endY'] ?? 0).toDouble(),
    width: (m['width'] ?? 4).toDouble(),
    color: m['color'] ?? '0xFF000000',
    dashPattern: m['dashPattern'] != null
        ? List<double>.from(m['dashPattern']).map((e) => e.toDouble()).toList()
        : null,
    creatorId: m['creatorId'] ?? '',
  );
}

class ChatMessage {
  final String id;
  final String from;
  final String uid;
  final String message;
  final DateTime timestamp;
  ChatMessage({
    required this.id,
    required this.from,
    required this.uid,
    required this.message,
    required this.timestamp,
  });
  Map<String, dynamic> toMap() => {
    'id': id,
    'from': from,
    'uid': uid,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
  };
  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
    id: m['id'] ?? const Uuid().v4(),
    from: m['from'] ?? 'زائر',
    uid: m['uid'] ?? '',
    message: m['message'] ?? '',
    timestamp: DateTime.tryParse(m['timestamp'] ?? '') ?? DateTime.now(),
  );
}

class LessonRoomPage extends StatefulWidget {
  final String lessonId;
  const LessonRoomPage({super.key, required this.lessonId});
  @override
  State<LessonRoomPage> createState() => _LessonRoomPageState();
}

class _LessonRoomPageState extends State<LessonRoomPage>
    with SingleTickerProviderStateMixin {
  final Uuid _uuid = const Uuid();

  late final String _selfId;
  late final String _displayName;
  late final String? _profileImageUrl;

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  final Map<String, RTCDataChannel> _whiteboardChannels = {};
  final Map<String, RTCDataChannel> _chatChannels = {};
  final Map<String, RTCDataChannel> _controlChannels = {};
  MediaStream? _localStream;
  MediaStream? _screenStream;
  bool _micOn = true;
  bool _camOn = false;
  String? _focusedUser;
  bool _isScreenSharing = false;

  final List<Stroke> _strokes = [];
  final List<WhiteboardText> _texts = [];
  final List<Line> _lines = [];
  final List<Offset> _currentPoints = [];
  bool _drawing = false;
  bool _eraserMode = false;
  bool _lineMode = false;
  bool _textMode = false;
  Offset? _lineStart;
  Offset? _lineEnd;
  Color _drawColor = Colors.black;
  double _strokeWidth = 4.0;
  final List<Stroke> _undoStack = [];
  final List<Stroke> _redoStack = [];
  bool _whiteboardOpen = false;
  String? _whiteboardCreatorId;
  String? _selectedTextId;
  bool _showWhiteboardMessage = true;
  bool _textDragging = false;
  bool _textResizing = false;
  bool _textRotating = false;
  double _textResizeStartScale = 1.0;
  double _textRotateStartAngle = 0.0;
  Offset _textDragStart = Offset.zero;
  final TextEditingController _textInputController = TextEditingController();
  final FocusNode _textInputFocusNode = FocusNode();
  OverlayEntry? _textInputOverlay;

  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScroll = ScrollController();
  final ScrollController _participantsScroll = ScrollController();
  final List<ChatMessage> _chatMessages = [];
  String _meetingTitle = 'اجتماع';
  bool _isCreator = false;
  final List<Map<String, dynamic>> _participantsList = [];
  Timer? _cleanupTimer;
  Timer? _creatorAbsenceTimer;
  bool _sessionPaused = false;
  DateTime? _creatorLeftTime;

  String? _roomId;
  StreamSubscription? _signalSubscription;
  StreamSubscription? _usersSubscription;
  StreamSubscription? _roomSubscription;
  String? _teacherId;
  final List<String> _hostedUsers = [];
  final Map<String, bool> _raisedHands = {};
  final Map<String, bool> _isSpeaking = {};
  final Map<String, Timer> _speakingTimers = {};
  late AnimationController _raiseHandAnimationController;
  late Animation<double> _raiseHandAnimation;

  int _cameraCount = 0;
  int _microphoneCount = 0;
  bool _hasMultipleCameras = false;
  bool _hasCamera = true;
  bool _hasMicrophone = true;
  List<MediaDeviceInfo> _videoDevices = [];

  bool get _isHosted => _isCreator || _hostedUsers.contains(_selfId);
  bool get _isMobile => MediaQuery.of(context).size.width < 600;
  bool get _isTablet =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 900;
  bool get _isDesktop => MediaQuery.of(context).size.width >= 900;
  double get _screenWidth => MediaQuery.of(context).size.width;
  double get _screenHeight => MediaQuery.of(context).size.height;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  OverlayEntry? _screenShareOverlay;
  Timer? _screenShareTimer;
  String _roomCode = "جار التحميل...";

  @override
  void initState() {
    super.initState();
    _selfId = currentUser.value?.id ?? _uuid.v4();
    _displayName = currentUser.value?.displayName ?? 'زائر';
    _profileImageUrl = currentUser.value?.photoUrl;
    _roomId = widget.lessonId;

    _raiseHandAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _raiseHandAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.2), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 1.0), weight: 1),
    ]).animate(_raiseHandAnimationController);

    _initBackground();
    _initLocalMedia();
    _joinRoom(_roomId!, _selfId);
    _startCleanupTimer();
    _startCreatorPresenceCheck();
    _fetchRoomCode();
  }

  Future<void> _initBackground() async {
    const androidConfig = FlutterBackgroundAndroidConfig(
      notificationTitle: "الدليل التعليمي",
      notificationText: "مشاركة الشاشة قيد التشغيل",
      notificationImportance: AndroidNotificationImportance.normal,
      notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
    );
    await FlutterBackground.initialize(androidConfig: androidConfig);
  }

  Future<void> _fetchRoomCode() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('lessons').doc(_roomId).get();
      if (doc.exists && mounted) {
        setState(() {
          _roomCode = doc.data()?['code'] ?? 'غير متوفر';
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _leaveRoom();
    _localRenderer.dispose();
    for (var r in _remoteRenderers.values) {
      r.dispose();
    }
    _localStream?.dispose();
    _screenStream?.dispose();
    for (var pc in _peerConnections.values) {
      pc.close();
    }
    _signalSubscription?.cancel();
    _usersSubscription?.cancel();
    _roomSubscription?.cancel();
    _cleanupTimer?.cancel();
    _creatorAbsenceTimer?.cancel();
    _chatController.dispose();
    _chatScroll.dispose();
    _participantsScroll.dispose();
    _textInputController.dispose();
    _textInputFocusNode.dispose();
    _removeTextInputOverlay();
    _raiseHandAnimationController.dispose();
    for (var timer in _speakingTimers.values) {
      timer.cancel();
    }
    _speakingTimers.clear();
    _removeScreenShareOverlay();
    _screenShareTimer?.cancel();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مغادرة الدرس'),
        content: const Text('هل أنت متأكد من أنك تريد المغادرة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('مغادرة'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _startCreatorPresenceCheck() {
    _creatorAbsenceTimer = Timer.periodic(const Duration(seconds: 10), (
      timer,
    ) async {
      if (_isCreator || _teacherId == null) return;
      final userDoc = await FirebaseFirestore.instance
          .collection('lessons')
          .doc(_roomId)
          .collection('users')
          .doc(_teacherId!)
          .get();
      if (!userDoc.exists) {
        if (_creatorLeftTime == null) {
          _creatorLeftTime = DateTime.now();
          setState(() {
            _sessionPaused = true;
            if (_whiteboardOpen && _whiteboardCreatorId == _teacherId) {
              _whiteboardOpen = false;
              _broadcastWhiteboardState(false);
            }
          });
          _pauseSession();
        } else {
          final duration = DateTime.now().difference(_creatorLeftTime!);
          if (duration.inHours >= 1) {
            timer.cancel();
            if (mounted) Navigator.pop(context);
          }
        }
      } else {
        if (_sessionPaused) {
          _creatorLeftTime = null;
          setState(() {
            _sessionPaused = false;
          });
          _resumeSession();
        }
      }
    });
  }

  void _pauseSession() {
    _applyMicState(false);
    _applyCamState(false);
    _stopScreenShare();
    if (_whiteboardOpen) {
      _toggleWhiteboard();
    }
  }

  void _resumeSession() {
    _applyMicState(true);
    if (_hasCamera) {
      _applyCamState(true);
    }
  }

  Future<void> _initLocalMedia() async {
    await _localRenderer.initialize();
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      _videoDevices = devices
          .where((device) => device.kind == 'videoinput')
          .toList();
      _cameraCount = _videoDevices.length;
      _microphoneCount = devices
          .where((device) => device.kind == 'audioinput')
          .length;
      _hasCamera = _cameraCount > 0;
      _hasMicrophone = _microphoneCount > 0;
      _hasMultipleCameras = _cameraCount > 1;
      _camOn = _hasCamera && _camOn;
      _micOn = _hasMicrophone && _micOn;
      setState(() {});
    } catch (_) {}

    final constraints = {
      'audio': _hasMicrophone,
      'video': _hasCamera
          ? {
              'facingMode': 'user',
              'width': {'ideal': 640},
              'height': {'ideal': 480},
            }
          : false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      if (_hasCamera) {
        _localStream!.getVideoTracks().forEach((track) {
          track.enabled = _camOn;
        });
      }
      if (_hasMicrophone) {
        _localStream!.getAudioTracks().forEach((track) {
          track.enabled = _micOn;
        });
      }
      _localRenderer.srcObject = _localStream;
      setState(() {});
    } catch (_) {}
  }

  Future<RTCPeerConnection> _createPeerConnection(
    String peerId,
    bool isOffer,
  ) async {
    final pc = await createPeerConnection(_configuration);
    pc.onIceCandidate = (candidate) {
      _sendSignalToPeer(peerId, {'ice': candidate.toMap()});
    };
    pc.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _handlePeerDisconnection(peerId);
      }
    };
    pc.onAddStream = (stream) {
      final renderer = RTCVideoRenderer();
      renderer.initialize().then((_) {
        renderer.srcObject = stream;
        setState(() {
          _remoteRenderers[peerId] = renderer;
          _updateAutoFocus();
        });
      });
    };
    pc.onDataChannel = (channel) {
      _setupDataChannels(peerId, channel);
    };
    _localStream?.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });
    if (isOffer) {
      final whiteboardChannel = await pc.createDataChannel(
        'whiteboard_channel',
        RTCDataChannelInit(),
      );
      final chatChannel = await pc.createDataChannel(
        'chat_channel',
        RTCDataChannelInit(),
      );
      final controlChannel = await pc.createDataChannel(
        'control_channel',
        RTCDataChannelInit(),
      );
      _setupDataChannels(peerId, whiteboardChannel);
      _setupDataChannels(peerId, chatChannel);
      _setupDataChannels(peerId, controlChannel);
    }
    _peerConnections[peerId] = pc;
    return pc;
  }

  void _setupDataChannels(String peerId, RTCDataChannel channel) {
    if (channel.label == 'whiteboard_channel') {
      _whiteboardChannels[peerId] = channel;
    } else if (channel.label == 'chat_channel') {
      _chatChannels[peerId] = channel;
    } else if (channel.label == 'control_channel') {
      _controlChannels[peerId] = channel;
      channel.onMessage = (message) {
        if (message.isBinary) return;
        _handleControlMessage(peerId, message.text);
      };
    } else {
      return;
    }
    if (channel.label != 'control_channel') {
      channel.onMessage = (message) {
        if (message.isBinary) return;
        _handleDataChannelMessage(peerId, channel.label!, message.text);
      };
    }
  }

  void _handleControlMessage(String peerId, String data) {
    try {
      final payload = jsonDecode(data);
      if (payload['type'] == 'hosted_update') {
        setState(() {
          _hostedUsers.clear();
          if (payload['hosted'] is List) {
            _hostedUsers.addAll(List<String>.from(payload['hosted']));
          }
        });
      } else if (payload['type'] == 'whiteboard_state') {
        final visible = payload['visible'] ?? false;
        final creatorId = payload['creatorId'];
        setState(() {
          _whiteboardOpen = visible;
          _whiteboardCreatorId = creatorId;
          _showWhiteboardMessage = true;
        });
      } else if (payload['type'] == 'whiteboard_stroke') {
        setState(() {
          _strokes.add(Stroke.fromMap(payload['data']));
        });
      } else if (payload['type'] == 'whiteboard_clear') {
        setState(() {
          _strokes.clear();
          _texts.clear();
          _lines.clear();
        });
      } else if (payload['type'] == 'whiteboard_undo') {
        if (_strokes.isNotEmpty) {
          setState(() {
            _undoStack.add(_strokes.removeLast());
          });
        }
      } else if (payload['type'] == 'whiteboard_redo') {
        if (_undoStack.isNotEmpty) {
          setState(() {
            _strokes.add(_undoStack.removeLast());
          });
        }
      } else if (payload['type'] == 'whiteboard_text') {
        setState(() {
          _texts.add(WhiteboardText.fromMap(payload['data']));
        });
      } else if (payload['type'] == 'whiteboard_line') {
        setState(() {
          _lines.add(Line.fromMap(payload['data']));
        });
      } else if (payload['type'] == 'whiteboard_text_update') {
        final textId = payload['textId'];
        final textData = payload['data'];
        setState(() {
          final index = _texts.indexWhere((t) => t.id == textId);
          if (index != -1) {
            _texts[index] = WhiteboardText.fromMap(textData);
          }
        });
      } else if (payload['type'] == 'whiteboard_text_delete') {
        final textId = payload['textId'];
        setState(() {
          _texts.removeWhere((t) => t.id == textId);
        });
      } else if (payload['type'] == 'user_muted') {
        final userId = payload['userId'];
        if (userId == _selfId) {
          _applyMicState(false);
        }
      } else if (payload['type'] == 'user_camera_disabled') {
        final userId = payload['userId'];
        if (userId == _selfId) {
          _applyCamState(false);
        }
      } else if (payload['type'] == 'user_whiteboard_disabled') {
        final userId = payload['userId'];
        if (userId == _selfId) {
          setState(() {
            if (_whiteboardOpen && _isHosted) {
              _whiteboardOpen = false;
            }
          });
        }
      } else if (payload['type'] == 'raise_hand') {
        final userId = payload['userId'];
        final raised = payload['raised'] ?? false;
        setState(() {
          _raisedHands[userId] = raised;
          if (raised && userId != _selfId) {
            if (_raiseHandAnimationController.isAnimating) {
              _raiseHandAnimationController.repeat();
            }
          }
        });
      } else if (payload['type'] == 'speaking') {
        final userId = payload['userId'];
        final speaking = payload['speaking'] ?? false;
        setState(() {
          _isSpeaking[userId] = speaking;
          if (speaking) {
            if (_speakingTimers.containsKey(userId)) {
              _speakingTimers[userId]?.cancel();
            }
            _speakingTimers[userId] = Timer(const Duration(seconds: 2), () {
              setState(() {
                _isSpeaking.remove(userId);
                _speakingTimers.remove(userId);
              });
            });
          }
        });
      }
    } catch (_) {}
  }

  void _handleDataChannelMessage(String peerId, String label, String data) {
    try {
      final payload = jsonDecode(data);
      if (label == 'whiteboard_channel') {
        if (payload['type'] == 'stroke') {
          setState(() {
            _strokes.add(Stroke.fromMap(payload['data']));
          });
        } else if (payload['type'] == 'text') {
          setState(() {
            _texts.add(WhiteboardText.fromMap(payload['data']));
          });
        } else if (payload['type'] == 'line') {
          setState(() {
            _lines.add(Line.fromMap(payload['data']));
          });
        } else if (payload['type'] == 'clear') {
          setState(() {
            _strokes.clear();
            _texts.clear();
            _lines.clear();
          });
        }
      } else if (label == 'chat_channel') {
        setState(() {
          _chatMessages.add(ChatMessage.fromMap(payload));
          _scrollToBottom();
        });
      }
    } catch (_) {}
  }

  Future<void> _createOffer(String peerId) async {
    final pc = await _createPeerConnection(peerId, true);
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    _sendSignalToPeer(peerId, {'sdp': offer.toMap()});
  }

  Future<void> _createAnswer(String peerId, RTCSessionDescription offer) async {
    final pc = await _createPeerConnection(peerId, false);
    await pc.setRemoteDescription(offer);
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    _sendSignalToPeer(peerId, {'sdp': answer.toMap()});
  }

  void _handleSignalMessage(String senderId, Map<String, dynamic> data) async {
    final pc = _peerConnections[senderId];
    if (data.containsKey('sdp')) {
      final sdpData = data['sdp'];
      final sdp = RTCSessionDescription(sdpData['sdp'], sdpData['type']);
      if (sdp.type == 'offer') {
        if (pc == null) {
          await _createAnswer(senderId, sdp);
        } else {
          await pc.setRemoteDescription(sdp);
        }
      } else if (sdp.type == 'answer') {
        await pc?.setRemoteDescription(sdp);
      }
    } else if (data.containsKey('ice')) {
      final candidateMap = data['ice'];
      final candidate = RTCIceCandidate(
        candidateMap['candidate'],
        candidateMap['sdpMid'],
        candidateMap['sdpMLineIndex'],
      );
      await pc?.addCandidate(candidate);
    }
  }

  void _handlePeerDisconnection(String peerId) {
    setState(() {
      _peerConnections.remove(peerId)?.close();
      _remoteRenderers.remove(peerId)?.dispose();
      _whiteboardChannels.remove(peerId);
      _chatChannels.remove(peerId);
      _controlChannels.remove(peerId);
      _participantsList.removeWhere((p) => p['id'] == peerId);
      if (_focusedUser == peerId) _focusedUser = null;
      if (_hostedUsers.contains(peerId)) {
        _hostedUsers.remove(peerId);
        _broadcastHostedUpdate();
      }
      _raisedHands.remove(peerId);
      _isSpeaking.remove(peerId);
      _speakingTimers.remove(peerId)?.cancel();
      if (_whiteboardCreatorId == peerId) {
        _whiteboardOpen = false;
        _whiteboardCreatorId = null;
      }
    });
  }

  void _broadcastWhiteboardState(bool visible) {
    final message = jsonEncode({
      'type': 'whiteboard_state',
      'visible': visible,
      'creatorId': _selfId,
    });
    for (final dc in _controlChannels.values) {
      if (dc.state == RTCDataChannelState.RTCDataChannelOpen) {
        dc.send(RTCDataChannelMessage(message));
      }
    }
  }

  void _broadcastWhiteboardStroke(Stroke stroke) {
    final message = jsonEncode({
      'type': 'whiteboard_stroke',
      'data': stroke.toMap(),
    });
    for (final dc in _whiteboardChannels.values) {
      if (dc.state == RTCDataChannelState.RTCDataChannelOpen) {
        dc.send(RTCDataChannelMessage(message));
      }
    }
  }

  void _broadcastWhiteboardLine(Line line) {
    final message = jsonEncode({
      'type': 'whiteboard_line',
      'data': line.toMap(),
    });
    for (final dc in _whiteboardChannels.values) {
      if (dc.state == RTCDataChannelState.RTCDataChannelOpen) {
        dc.send(RTCDataChannelMessage(message));
      }
    }
  }

  void _broadcastWhiteboardText(WhiteboardText text) {
    final message = jsonEncode({
      'type': 'whiteboard_text',
      'data': text.toMap(),
    });
    for (final dc in _whiteboardChannels.values) {
      if (dc.state == RTCDataChannelState.RTCDataChannelOpen) {
        dc.send(RTCDataChannelMessage(message));
      }
    }
  }

  void _broadcastWhiteboardTextUpdate(String textId, WhiteboardText text) {
    final message = jsonEncode({
      'type': 'whiteboard_text_update',
      'textId': textId,
      'data': text.toMap(),
    });
    for (final dc in _whiteboardChannels.values) {
      if (dc.state == RTCDataChannelState.RTCDataChannelOpen) {
        dc.send(RTCDataChannelMessage(message));
      }
    }
  }

  void _broadcastWhiteboardTextDelete(String textId) {
    final message = jsonEncode({
      'type': 'whiteboard_text_delete',
      'textId': textId,
    });
    for (final dc in _whiteboardChannels.values) {
      if (dc.state == RTCDataChannelState.RTCDataChannelOpen) {
        dc.send(RTCDataChannelMessage(message));
      }
    }
  }

  void _broadcastWhiteboardClear() {
    final message = jsonEncode({'type': 'whiteboard_clear'});
    for (final dc in _whiteboardChannels.values) {
      if (dc.state == RTCDataChannelState.RTCDataChannelOpen) {
        dc.send(RTCDataChannelMessage(message));
      }
    }
  }

  void _broadcastWhiteboardUndo() {
    final message = jsonEncode({'type': 'whiteboard_undo'});
    for (final dc in _whiteboardChannels.values) {
      if (dc.state == RTCDataChannelState.RTCDataChannelOpen) {
        dc.send(RTCDataChannelMessage(message));
      }
    }
  }

  void _broadcastWhiteboardRedo() {
    final message = jsonEncode({'type': 'whiteboard_redo'});
    for (final dc in _whiteboardChannels.values) {
      if (dc.state == RTCDataChannelState.RTCDataChannelOpen) {
        dc.send(RTCDataChannelMessage(message));
      }
    }
  }

  void _broadcastControlMessage(Map<String, dynamic> payload) {
    final message = jsonEncode(payload);
    for (final dc in _controlChannels.values) {
      if (dc.state == RTCDataChannelState.RTCDataChannelOpen) {
        dc.send(RTCDataChannelMessage(message));
      }
    }
  }

  void _broadcastRaiseHand(bool raised) {
    _broadcastControlMessage({
      'type': 'raise_hand',
      'userId': _selfId,
      'raised': raised,
    });
  }

  void _broadcastSpeaking(bool speaking) {
    _broadcastControlMessage({
      'type': 'speaking',
      'userId': _selfId,
      'speaking': speaking,
    });
  }

  void _sendChatMessage(String message) {
    if (message.trim().isEmpty) return;
    final chatMsg = ChatMessage(
      id: _uuid.v4(),
      from: _displayName,
      uid: _selfId,
      message: message,
      timestamp: DateTime.now(),
    );
    final data = jsonEncode(chatMsg.toMap());
    setState(() {
      _chatMessages.add(chatMsg);
    });
    _chatController.clear();
    _scrollToBottom();
    for (final dc in _chatChannels.values) {
      if (dc.state == RTCDataChannelState.RTCDataChannelOpen) {
        dc.send(RTCDataChannelMessage(data));
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _commitStroke(List<Offset> pts) {
    if (pts.length < 2) return;
    final stroke = Stroke(
      id: _uuid.v4(),
      points: pts.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      width: _strokeWidth,
      color: _drawColor.value.toRadixString(16),
      isEraser: _eraserMode,
      creatorId: _selfId,
    );
    setState(() {
      _strokes.add(stroke);
      _undoStack.clear();
    });
    _broadcastWhiteboardStroke(stroke);
  }

  void _commitLine(Offset start, Offset end) {
    final line = Line(
      id: _uuid.v4(),
      startX: start.dx,
      startY: start.dy,
      endX: end.dx,
      endY: end.dy,
      width: _strokeWidth,
      color: _drawColor.value.toRadixString(16),
      creatorId: _selfId,
    );
    setState(() {
      _lines.add(line);
      _undoStack.clear();
    });
    _broadcastWhiteboardLine(line);
  }

  void _addText(Offset position, String text) {
    final whiteboardText = WhiteboardText(
      id: _uuid.v4(),
      text: text,
      x: position.dx,
      y: position.dy,
      bold: false,
      fontSize: 24,
      color: _drawColor.value.toRadixString(16),
      creatorId: _selfId,
    );
    setState(() {
      _texts.add(whiteboardText);
      _selectedTextId = whiteboardText.id;
    });
    _broadcastWhiteboardText(whiteboardText);
  }

  void _updateText(WhiteboardText text) {
    final index = _texts.indexWhere((t) => t.id == text.id);
    if (index != -1) {
      setState(() {
        _texts[index] = text;
      });
      _broadcastWhiteboardTextUpdate(text.id, text);
    }
  }

  void _deleteText(String textId) {
    setState(() {
      _texts.removeWhere((t) => t.id == textId);
      if (_selectedTextId == textId) {
        _selectedTextId = null;
      }
    });
    _broadcastWhiteboardTextDelete(textId);
  }

  void _clearBoard() {
    setState(() {
      _strokes.clear();
      _texts.clear();
      _lines.clear();
      _undoStack.clear();
      _redoStack.clear();
      _selectedTextId = null;
    });
    _broadcastWhiteboardClear();
  }

  void _undo() {
    if (_strokes.isNotEmpty) {
      final lastStroke = _strokes.removeLast();
      _undoStack.add(lastStroke);
      setState(() {});
      _broadcastWhiteboardUndo();
    }
  }

  void _redo() {
    if (_undoStack.isNotEmpty) {
      final redoStroke = _undoStack.removeLast();
      _strokes.add(redoStroke);
      setState(() {});
      _broadcastWhiteboardRedo();
    }
  }

  Future<void> _switchCamera() async {
    final tracks = _localStream?.getVideoTracks();
    if (tracks == null || tracks.isEmpty || !_hasMultipleCameras) return;
    try {
      await Helper.switchCamera(tracks.first);
    } catch (_) {}
  }

  void _applyMicState(bool enable) {
    if (!_hasMicrophone) return;
    _localStream?.getAudioTracks().forEach((track) => track.enabled = enable);
    setState(() => _micOn = enable);
    if (_roomId != null) {
      FirebaseFirestore.instance
          .collection('lessons')
          .doc(_roomId)
          .collection('users')
          .doc(_selfId)
          .update({'micOn': enable});
    }
  }

  void _applyCamState(bool enable) {
    if (!_hasCamera) return;
    _localStream?.getVideoTracks().forEach((track) => track.enabled = enable);
    setState(() => _camOn = enable);
    if (enable && _isHosted) {
      _updateAutoFocus();
    }
    if (_roomId != null) {
      FirebaseFirestore.instance
          .collection('lessons')
          .doc(_roomId)
          .collection('users')
          .doc(_selfId)
          .update({'camOn': enable});
    }
  }

  void _muteUser(String userId) {
    _broadcastControlMessage({'type': 'user_muted', 'userId': userId});
  }

  void _disableUserCamera(String userId) {
    _broadcastControlMessage({
      'type': 'user_camera_disabled',
      'userId': userId,
    });
  }

  void _disableUserWhiteboard(String userId) {
    _broadcastControlMessage({
      'type': 'user_whiteboard_disabled',
      'userId': userId,
    });
  }

  void _toggleRaiseHand() {
    final newState = !(_raisedHands[_selfId] ?? false);
    setState(() {
      _raisedHands[_selfId] = newState;
    });
    _broadcastRaiseHand(newState);
    if (newState) {
      _raiseHandAnimationController.repeat();
    } else {
      _raiseHandAnimationController.stop();
    }
    if (_roomId != null) {
      FirebaseFirestore.instance
          .collection('lessons')
          .doc(_roomId)
          .collection('users')
          .doc(_selfId)
          .update({'handRaised': newState});
    }
  }

  Future<void> _startScreenShare() async {
    try {
      await FlutterBackground.enableBackgroundExecution();
      final stream = await navigator.mediaDevices.getDisplayMedia({
        'video': {
          'frameRate': 15,
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
        'audio': false,
      });
      if (stream.getVideoTracks().isEmpty) {
        stream.dispose();
        await FlutterBackground.disableBackgroundExecution();
        return;
      }
      _screenStream = stream;
      final videoTrack = _screenStream!.getVideoTracks().first;
      videoTrack.onEnded = () {
        _stopScreenShare();
      };
      for (final pc in _peerConnections.values) {
        final senders = await pc.getSenders();
        RTCRtpSender? videoSender;
        for (final sender in senders) {
          if (sender.track?.kind == 'video') {
            videoSender = sender;
            break;
          }
        }
        if (videoSender != null) {
          await videoSender.replaceTrack(videoTrack);
        } else {
          pc.addTrack(videoTrack, _screenStream!);
        }
      }
      setState(() {
        _isScreenSharing = true;
        _updateAutoFocus();
      });
      _showScreenShareOverlay();
    } catch (_) {
      await FlutterBackground.disableBackgroundExecution();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل في مشاركة الشاشة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopScreenShare() async {
    try {
      if (_screenStream != null) {
        _screenStream!.getTracks().forEach((track) => track.stop());
        _screenStream!.dispose();
        _screenStream = null;
      }
      final localVideoTrack = _localStream?.getVideoTracks().first;
      for (final pc in _peerConnections.values) {
        final senders = await pc.getSenders();
        RTCRtpSender? videoSender;
        for (final sender in senders) {
          if (sender.track?.kind == 'video') {
            videoSender = sender;
            break;
          }
        }
        if (videoSender != null && localVideoTrack != null) {
          await videoSender.replaceTrack(localVideoTrack);
        }
      }
      await FlutterBackground.disableBackgroundExecution();
      setState(() {
        _isScreenSharing = false;
        _updateAutoFocus();
      });
      _removeScreenShareOverlay();
    } catch (_) {}
  }

  void _showScreenShareOverlay() {
    _removeScreenShareOverlay();
    final overlay = Overlay.of(context);
    _screenShareOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 10,
        right: 10,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.screen_share, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'جاري مشاركة الشاشة',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.stop, size: 16),
                  label: const Text('إنهاء'),
                  onPressed: _stopScreenShare,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    overlay.insert(_screenShareOverlay!);
  }

  void _removeScreenShareOverlay() {
    _screenShareOverlay?.remove();
    _screenShareOverlay = null;
  }

  void _toggleWhiteboard() {
    if (!_isHosted) return;
    final newState = !_whiteboardOpen;
    setState(() {
      _whiteboardOpen = newState;
      if (newState) {
        _whiteboardCreatorId = _selfId;
        _showWhiteboardMessage = true;
      } else {
        _whiteboardCreatorId = null;
      }
    });
    _broadcastWhiteboardState(newState);
  }

  bool _canEditWhiteboard() {
    return _isHosted && _whiteboardCreatorId == _selfId;
  }

  void _showTextInputDialog(Offset position) {
    if (!_canEditWhiteboard()) return;
    _textInputController.clear();
    _removeTextInputOverlay();
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final globalPosition = renderBox.localToGlobal(position);
    _textInputOverlay = OverlayEntry(
      builder: (context) => Positioned(
        left: max(0, min(globalPosition.dx, _screenWidth - 200)),
        top: max(0, min(globalPosition.dy, _screenHeight - 200)),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8),
              ],
            ),
            child: SizedBox(
              width: 200,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _textInputController,
                    focusNode: _textInputFocusNode,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'أدخل النص...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(8),
                    ),
                    onSubmitted: (text) {
                      if (text.trim().isNotEmpty) {
                        _addText(position, text);
                      }
                      _removeTextInputOverlay();
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            if (_textInputController.text.trim().isNotEmpty) {
                              _addText(
                                position,
                                _textInputController.text.trim(),
                              );
                            }
                            _removeTextInputOverlay();
                          },
                          child: const Text('إضافة'),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: _removeTextInputOverlay,
                          child: const Text('إلغاء'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_textInputOverlay!);
    _textInputFocusNode.requestFocus();
  }

  void _removeTextInputOverlay() {
    _textInputOverlay?.remove();
    _textInputOverlay = null;
    _textInputFocusNode.unfocus();
  }

  void _handleTextTap(WhiteboardText text, Offset localPosition) {
    if (!_canEditWhiteboard() || text.creatorId != _selfId) return;
    final textRect = Rect.fromLTWH(
      text.x - 4,
      text.y - 4,
      text.text.length * text.fontSize / 2 + 8,
      text.fontSize + 8,
    );
    if (textRect.contains(localPosition)) {
      setState(() {
        _selectedTextId = text.id;
      });
    }
  }

  void _handleTextDragStart(WhiteboardText text, Offset localPosition) {
    if (!_canEditWhiteboard() ||
        _selectedTextId != text.id ||
        text.creatorId != _selfId) {
      return;
    }
    final textRect = Rect.fromLTWH(
      text.x - 4,
      text.y - 4,
      text.text.length * text.fontSize / 2 + 8,
      text.fontSize + 8,
    );
    if (textRect.contains(localPosition)) {
      setState(() {
        _textDragging = true;
        _textDragStart = localPosition;
      });
    }
  }

  void _handleTextDragUpdate(WhiteboardText text, Offset localPosition) {
    if (!_canEditWhiteboard() ||
        !_textDragging ||
        _selectedTextId != text.id ||
        text.creatorId != _selfId) {
      return;
    }
    final dx = localPosition.dx - _textDragStart.dx;
    final dy = localPosition.dy - _textDragStart.dy;
    final updatedText = WhiteboardText(
      id: text.id,
      text: text.text,
      x: text.x + dx,
      y: text.y + dy,
      bold: text.bold,
      fontSize: text.fontSize,
      rotation: text.rotation,
      scale: text.scale,
      color: text.color,
      creatorId: text.creatorId,
    );
    _updateText(updatedText);
    setState(() {
      _textDragStart = localPosition;
    });
  }

  void _handleTextDragEnd() {
    if (_textDragging) {
      setState(() {
        _textDragging = false;
      });
    }
  }

  void _handleTextResizeStart(WhiteboardText text, Offset localPosition) {
    if (!_canEditWhiteboard() ||
        _selectedTextId != text.id ||
        text.creatorId != _selfId) {
      return;
    }
    final resizeHandle = Rect.fromCircle(
      center: Offset(
        text.x + text.text.length * text.fontSize / 2,
        text.y + text.fontSize,
      ),
      radius: 10,
    );
    if (resizeHandle.contains(localPosition)) {
      setState(() {
        _textResizing = true;
        _textResizeStartScale = text.scale;
      });
    }
  }

  void _handleTextResizeUpdate(WhiteboardText text, Offset localPosition) {
    if (!_canEditWhiteboard() ||
        !_textResizing ||
        _selectedTextId != text.id ||
        text.creatorId != _selfId) {
      return;
    }
    final originalSize = text.text.length * text.fontSize / 2;
    final newSize = max(10.0, originalSize + (localPosition.dx - text.x));
    final newScale = max(0.5, min(5.0, newSize / originalSize));
    final updatedText = WhiteboardText(
      id: text.id,
      text: text.text,
      x: text.x,
      y: text.y,
      bold: text.bold,
      fontSize: text.fontSize,
      rotation: text.rotation,
      scale: newScale,
      color: text.color,
      creatorId: text.creatorId,
    );
    _updateText(updatedText);
  }

  void _handleTextResizeEnd() {
    if (_textResizing) {
      setState(() {
        _textResizing = false;
      });
    }
  }

  void _handleTextRotateStart(WhiteboardText text, Offset localPosition) {
    if (!_canEditWhiteboard() ||
        _selectedTextId != text.id ||
        text.creatorId != _selfId) {
      return;
    }
    final rotateHandle = Rect.fromCircle(
      center: Offset(text.x - 10, text.y + text.fontSize / 2),
      radius: 10,
    );
    if (rotateHandle.contains(localPosition)) {
      setState(() {
        _textRotating = true;
        _textRotateStartAngle = text.rotation;
      });
    }
  }

  void _handleTextRotateUpdate(WhiteboardText text, Offset localPosition) {
    if (!_canEditWhiteboard() ||
        !_textRotating ||
        _selectedTextId != text.id ||
        text.creatorId != _selfId) {
      return;
    }
    final center = Offset(
      text.x + text.text.length * text.fontSize / 4,
      text.y + text.fontSize / 2,
    );
    final angle = atan2(
      localPosition.dy - center.dy,
      localPosition.dx - center.dx,
    );
    final newRotation = (angle * 180 / pi) % 360;
    final updatedText = WhiteboardText(
      id: text.id,
      text: text.text,
      x: text.x,
      y: text.y,
      bold: text.bold,
      fontSize: text.fontSize,
      rotation: newRotation,
      scale: text.scale,
      color: text.color,
      creatorId: text.creatorId,
    );
    _updateText(updatedText);
  }

  void _handleTextRotateEnd() {
    if (_textRotating) {
      setState(() {
        _textRotating = false;
      });
    }
  }

  void _stopSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنهاء الاجتماع'),
        content: const Text('هل أنت متأكد من إنهاء هذا الاجتماع؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إنهاء', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (_isCreator) {
        await FirebaseFirestore.instance
            .collection('lessons')
            .doc(_roomId)
            .delete();
      }
      _leaveRoom();
      if (mounted) Navigator.of(context).maybePop();
    }
  }

  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _participantsList.removeWhere(
        (p) => !_peerConnections.containsKey(p['id']),
      );
    });
  }

  void _joinRoom(String roomId, String selfId) async {
    final roomRef = FirebaseFirestore.instance.collection('lessons').doc(roomId);
    _roomSubscription = roomRef.snapshots().listen((snapshot) {
      if (!snapshot.exists) {
        _leaveRoom();
        if (mounted) Navigator.of(context).maybePop();
        return;
      }
      final data = snapshot.data();
      setState(() {
        _meetingTitle = data?['title'] ?? 'اجتماع';
        _teacherId = data?['teacherId'];
        _isCreator = _teacherId == _selfId;
      });
    });
    await roomRef.collection('users').doc(selfId).set({
      'displayName': _displayName,
      'photoUrl': _profileImageUrl,
      'micOn': _micOn,
      'camOn': _camOn,
      'hasCamera': _hasCamera,
      'hasMic': _hasMicrophone,
      'isHosted': false,
      'handRaised': false,
      'lastSeen': FieldValue.serverTimestamp(),
      'joinedAt': FieldValue.serverTimestamp(),
    });
    _signalSubscription = roomRef
        .collection('signals')
        .where('recipientId', isEqualTo: selfId)
        .snapshots()
        .listen((snapshot) {
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final senderId = data['senderId'] as String;
            if (data.containsKey('sdp')) {
              _handleSignalMessage(senderId, {'sdp': data['sdp']});
            } else if (data.containsKey('ice')) {
              _handleSignalMessage(senderId, {'ice': data['ice']});
            }
            doc.reference.delete();
          }
        });
    _usersSubscription = roomRef.collection('users').snapshots().listen((
      snapshot,
    ) {
      for (final doc in snapshot.docs) {
        final peerId = doc.id;
        if (peerId == selfId) continue;
        final userData = doc.data();
        final displayName = userData['displayName'] ?? 'مجهول';
        if (!_peerConnections.containsKey(peerId) &&
            selfId.compareTo(peerId) < 0) {
          _createOffer(peerId);
        }
        final participantIndex = _participantsList.indexWhere(
          (p) => p['id'] == peerId,
        );
        if (participantIndex == -1) {
          setState(() {
            _participantsList.add({
              'id': peerId,
              'displayName': displayName,
              'photoUrl': userData['photoUrl'],
              'camOn': userData['camOn'] ?? false,
              'hasCamera': userData['hasCamera'] ?? true,
              'micOn': userData['micOn'] ?? true,
              'isHosted': userData['isHosted'] ?? false,
              'handRaised': userData['handRaised'] ?? false,
            });
            if (userData['isHosted'] == true) {
              _hostedUsers.add(peerId);
            }
            _raisedHands[peerId] = userData['handRaised'] ?? false;
          });
        } else {
          setState(() {
            _participantsList[participantIndex] = {
              'id': peerId,
              'displayName': displayName,
              'photoUrl': userData['photoUrl'],
              'camOn': userData['camOn'] ?? false,
              'hasCamera': userData['hasCamera'] ?? true,
              'micOn': userData['micOn'] ?? true,
              'isHosted': userData['isHosted'] ?? false,
              'handRaised': userData['handRaised'] ?? false,
            };
            if (userData['isHosted'] == true) {
              if (!_hostedUsers.contains(peerId)) {
                _hostedUsers.add(peerId);
              }
            } else {
              _hostedUsers.remove(peerId);
            }
            _raisedHands[peerId] = userData['handRaised'] ?? false;
          });
        }
      }
      final firestoreUserIds = snapshot.docs.map((doc) => doc.id).toSet();
      _participantsList.removeWhere(
        (participant) =>
            participant['id'] != selfId &&
            !firestoreUserIds.contains(participant['id']),
      );
      _updateAutoFocus();
    });
  }

  void _leaveRoom() async {
    _signalSubscription?.cancel();
    _usersSubscription?.cancel();
    _roomSubscription?.cancel();
    for (final id in _peerConnections.keys.toList()) {
      _handlePeerDisconnection(id);
    }
    if (_roomId != null) {
      await FirebaseFirestore.instance
          .collection('lessons')
          .doc(_roomId)
          .collection('users')
          .doc(_selfId)
          .delete();
    }
  }

  void _sendSignalToPeer(String peerId, Map<String, dynamic> signal) {
    final data = {
      ...signal,
      'senderId': _selfId,
      'recipientId': peerId,
      'timestamp': FieldValue.serverTimestamp(),
    };
    FirebaseFirestore.instance
        .collection('lessons')
        .doc(_roomId)
        .collection('signals')
        .add(data);
  }

  void _broadcastHostedUpdate() {
    final message = jsonEncode({
      'type': 'hosted_update',
      'hosted': _hostedUsers,
    });
    for (final dc in _controlChannels.values) {
      if (dc.state == RTCDataChannelState.RTCDataChannelOpen) {
        dc.send(RTCDataChannelMessage(message));
      }
    }
  }

  Future<void> _toggleHosted(String userId) async {
    if (!_isCreator) return;
    final userRef = FirebaseFirestore.instance
        .collection('lessons')
        .doc(_roomId)
        .collection('users')
        .doc(userId);
    final currentStatus = _hostedUsers.contains(userId);
    final newStatus = !currentStatus;
    await userRef.update({'isHosted': newStatus});
    setState(() {
      if (newStatus) {
        if (!_hostedUsers.contains(userId)) {
          _hostedUsers.add(userId);
        }
      } else {
        _hostedUsers.remove(userId);
      }
    });
    _broadcastHostedUpdate();
  }

  void _updateAutoFocus() {
    if (_isScreenSharing && _isHosted) {
      setState(() {
        _focusedUser = _selfId;
      });
      return;
    }
    final activeParticipants = _remoteRenderers.entries
        .where((e) => e.value.srcObject != null)
        .toList();
    if (activeParticipants.isEmpty) return;
    String? newFocus;
    for (final entry in activeParticipants) {
      final isUserHosted =
          _hostedUsers.contains(entry.key) || entry.key == _teacherId;
      if (isUserHosted && _remoteRenderers[entry.key]?.srcObject != null) {
        newFocus = entry.key;
        break;
      }
    }
    if (newFocus == null &&
        _teacherId != null &&
        activeParticipants.any((e) => e.key == _teacherId)) {
      newFocus = _teacherId;
    }
    if (newFocus == null && activeParticipants.isNotEmpty) {
      newFocus = activeParticipants.first.key;
    }
    if (newFocus != null && _focusedUser != newFocus) {
      setState(() {
        _focusedUser = newFocus;
      });
    }
  }

  Widget _buildVideoView(
    String userId,
    RTCVideoRenderer renderer,
    bool isRemote,
    Map<String, dynamic>? participantData,
  ) {
    final isSelf = userId == _selfId;
    final displayName = isSelf
        ? _displayName
        : participantData?['displayName'] ?? 'مجهول';
    final photoUrl = isSelf ? _profileImageUrl : participantData?['photoUrl'];
    final hasCamera = isSelf
        ? _hasCamera
        : participantData?['hasCamera'] ?? true;
    final camOn = isSelf ? _camOn : participantData?['camOn'] ?? false;
    final micOn = isSelf ? _micOn : participantData?['micOn'] ?? true;
    final showVideo =
        renderer.srcObject != null && (isSelf ? _camOn : camOn) && hasCamera;
    final isSpeaking = _isSpeaking[userId] ?? false;
    final handRaised = _raisedHands[userId] ?? false;
    return Stack(
      children: [
        if (showVideo)
          RTCVideoView(
            renderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            mirror: isSelf,
          )
        else
          Container(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (photoUrl != null && photoUrl.isNotEmpty)
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: NetworkImage(photoUrl),
                    )
                  else
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        displayName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 32,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (isSpeaking)
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green, width: 3),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        Positioned(
          bottom: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(
                  micOn ? Icons.mic : Icons.mic_off,
                  size: 12,
                  color: micOn ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        if (handRaised)
          Positioned(
            top: 8,
            right: 8,
            child: AnimatedBuilder(
              animation: _raiseHandAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _raiseHandAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.front_hand,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _zoomLayout(BuildContext context) {
    if (_isScreenSharing && _isHosted) {
      return Stack(
        children: [
          Positioned.fill(
            child: _screenStream != null
                ? RTCVideoView(
                    RTCVideoRenderer()
                      ..srcObject = _screenStream
                      ..initialize(),
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                  )
                : Container(color: Colors.black),
          ),
          Positioned(
            top: 16,
            right: 16,
            width: 120,
            height: 90,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: _buildVideoView(_selfId, _localRenderer, false, null),
            ),
          ),
        ],
      );
    }
    final participants = <String, RTCVideoRenderer>{};
    participants.addAll(_remoteRenderers);
    participants[_selfId] = _localRenderer;
    final activeParticipants = participants.entries
        .where((e) => e.value.srcObject != null)
        .toList();
    if (activeParticipants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
              CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(_profileImageUrl!),
              )
            else
              CircleAvatar(
                radius: 50,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.person, size: 50, color: Colors.white),
              ),
            const SizedBox(height: 16),
            Text(
              'لا يوجد بث فيديو نشط',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: _isMobile ? 14 : 16,
              ),
            ),
          ],
        ),
      );
    }
    final focusedId = _focusedUser ?? activeParticipants.first.key;
    final focusedRenderer =
        participants[focusedId] ?? activeParticipants.first.value;
    final others = activeParticipants.where((e) => e.key != focusedId).toList();
    if (_isMobile) {
      return Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildVideoView(
                  focusedId,
                  focusedRenderer,
                  focusedId != _selfId,
                  _participantsList.firstWhere(
                    (p) => p['id'] == focusedId,
                    orElse: () => {},
                  ),
                ),
              ),
            ),
          ),
          if (others.isNotEmpty)
            SizedBox(
              height: _screenHeight * 0.15,
              child: ListView.builder(
                controller: _participantsScroll,
                scrollDirection: Axis.horizontal,
                itemCount: others.length,
                itemBuilder: (context, index) {
                  final entry = others[index];
                  final participantData = _participantsList.firstWhere(
                    (p) => p['id'] == entry.key,
                    orElse: () => {},
                  );
                  return GestureDetector(
                    onTap: () => setState(() => _focusedUser = entry.key),
                    child: Container(
                      width: _screenWidth * 0.3,
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: entry.key == focusedId
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).dividerColor,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildVideoView(
                          entry.key,
                          entry.value,
                          true,
                          participantData,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      );
    } else if (_isTablet) {
      return Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildVideoView(
                  focusedId,
                  focusedRenderer,
                  focusedId != _selfId,
                  _participantsList.firstWhere(
                    (p) => p['id'] == focusedId,
                    orElse: () => {},
                  ),
                ),
              ),
            ),
          ),
          if (others.isNotEmpty)
            SizedBox(
              height: 120,
              child: ListView.builder(
                controller: _participantsScroll,
                scrollDirection: Axis.horizontal,
                itemCount: others.length,
                itemBuilder: (context, index) {
                  final entry = others[index];
                  final participantData = _participantsList.firstWhere(
                    (p) => p['id'] == entry.key,
                    orElse: () => {},
                  );
                  return GestureDetector(
                    onTap: () => setState(() => _focusedUser = entry.key),
                    child: Container(
                      width: 150,
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: entry.key == focusedId
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).dividerColor,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildVideoView(
                          entry.key,
                          entry.value,
                          true,
                          participantData,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      );
    } else {
      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _screenWidth > 1200 ? 3 : 2,
          childAspectRatio: 16 / 9,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: activeParticipants.length,
        itemBuilder: (context, index) {
          final entry = activeParticipants[index];
          final participantData = _participantsList.firstWhere(
            (p) => p['id'] == entry.key,
            orElse: () => {},
          );
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: entry.key == focusedId
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildVideoView(
                entry.key,
                entry.value,
                entry.key != _selfId,
                participantData,
              ),
            ),
          );
        },
      );
    }
  }

  Widget _whiteboardScreen(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      bottom: false,
      child: GestureDetector(
        onTapDown: (details) {
          if (!_canEditWhiteboard()) return;
          final localPosition = details.localPosition;
          if (_textMode) {
            _showTextInputDialog(localPosition);
            return;
          }
          for (final text in _texts) {
            _handleTextTap(text, localPosition);
          }
          if (_selectedTextId != null) {
            final selectedText = _texts.firstWhere(
              (t) => t.id == _selectedTextId!,
            );
            _handleTextResizeStart(selectedText, localPosition);
            _handleTextRotateStart(selectedText, localPosition);
            _handleTextDragStart(selectedText, localPosition);
          }
        },
        onPanStart: (details) {
          if (!_canEditWhiteboard()) return;
          final localPosition = details.localPosition;
          if (_lineMode) {
            setState(() {
              _lineStart = localPosition;
              _lineEnd = localPosition;
            });
            return;
          }
          if (_selectedTextId != null) {
            final selectedText = _texts.firstWhere(
              (t) => t.id == _selectedTextId!,
            );
            _handleTextDragStart(selectedText, localPosition);
            _handleTextResizeStart(selectedText, localPosition);
            _handleTextRotateStart(selectedText, localPosition);
          }
          if (!_textMode && !_lineMode) {
            setState(() {
              _drawing = true;
              _currentPoints.clear();
              _currentPoints.add(localPosition);
            });
          }
        },
        onPanUpdate: (details) {
          if (!_canEditWhiteboard()) return;
          final localPosition = details.localPosition;
          if (_lineMode && _lineStart != null) {
            setState(() {
              _lineEnd = localPosition;
            });
            return;
          }
          if (_selectedTextId != null &&
              (_textDragging || _textResizing || _textRotating)) {
            final selectedText = _texts.firstWhere(
              (t) => t.id == _selectedTextId!,
            );
            if (_textDragging) {
              _handleTextDragUpdate(selectedText, localPosition);
            } else if (_textResizing) {
              _handleTextResizeUpdate(selectedText, localPosition);
            } else if (_textRotating) {
              _handleTextRotateUpdate(selectedText, localPosition);
            }
            return;
          }
          if (_drawing) {
            setState(() => _currentPoints.add(localPosition));
          }
        },
        onPanEnd: (details) {
          if (!_canEditWhiteboard()) return;
          if (_lineMode && _lineStart != null && _lineEnd != null) {
            _commitLine(_lineStart!, _lineEnd!);
            setState(() {
              _lineStart = null;
              _lineEnd = null;
            });
            return;
          }
          _handleTextDragEnd();
          _handleTextResizeEnd();
          _handleTextRotateEnd();
          if (_drawing) {
            setState(() => _drawing = false);
            if (_currentPoints.length >= 2) {
              _commitStroke(List<Offset>.from(_currentPoints));
              _currentPoints.clear();
            }
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _WhiteboardPainter(
                          strokes: _strokes,
                          texts: _texts,
                          lines: _lines,
                          selectedTextId: _selectedTextId,
                          isDark: isDark,
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ),
                if (_lineStart != null && _lineEnd != null)
                  CustomPaint(
                    painter: _PreviewLinePainter(
                      start: _lineStart!,
                      end: _lineEnd!,
                      width: _strokeWidth,
                      color: _drawColor,
                      isDark: isDark,
                    ),
                    size: Size.infinite,
                  ),
                if (_drawing && _currentPoints.isNotEmpty)
                  CustomPaint(
                    painter: _PreviewStrokePainter(
                      points: _currentPoints,
                      width: _strokeWidth,
                      color: _eraserMode
                          ? Colors.transparent
                          : _drawColor,
                      isEraser: _eraserMode,
                      isDark: isDark,
                    ),
                    size: Size.infinite,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDrawingTools() {
    if (!_canEditWhiteboard()) return const SizedBox();
    return Card(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...[
                  Colors.black,
                  Colors.red,
                  Colors.blue,
                  Colors.green,
                  Colors.amber,
                ].map((c) {
                  return GestureDetector(
                    onTap: () => setState(() {
                      _drawColor = c;
                      _eraserMode = false;
                      _lineMode = false;
                      _textMode = false;
                    }),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _drawColor == c
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.brush),
                  color: !_eraserMode && !_lineMode && !_textMode ? Colors.blue : Colors.grey,
                  onPressed: () => setState(() {
                    _eraserMode = false;
                    _lineMode = false;
                    _textMode = false;
                  }),
                ),
                IconButton(
                  icon: const Icon(Icons.cleaning_services),
                  color: _eraserMode ? Colors.red : Colors.grey,
                  onPressed: () => setState(() {
                    _eraserMode = true;
                    _lineMode = false;
                    _textMode = false;
                  }),
                ),
                IconButton(
                  icon: const Icon(Icons.show_chart),
                  color: _lineMode ? Colors.green : Colors.grey,
                  onPressed: () => setState(() {
                    _lineMode = true;
                    _eraserMode = false;
                    _textMode = false;
                  }),
                ),
                IconButton(
                  icon: const Icon(Icons.text_fields),
                  color: _textMode ? Colors.purple : Colors.grey,
                  onPressed: () => setState(() {
                    _textMode = true;
                    _eraserMode = false;
                    _lineMode = false;
                  }),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.undo), onPressed: _undo),
                IconButton(icon: const Icon(Icons.redo), onPressed: _redo),
                IconButton(icon: const Icon(Icons.delete), onPressed: _clearBoard),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomToolbar() {
    final buttonSize = _isMobile ? 44.0 : 52.0;
    final iconSize = _isMobile ? 22.0 : 26.0;
    final buttonSpacing = _isMobile ? 4.0 : 8.0;

    return Container(
      padding: EdgeInsets.only(
        top: _isMobile ? 12 : 16,
        bottom: MediaQuery.of(context).padding.bottom + (_isMobile ? 8 : 12),
        left: _isMobile ? 8 : 16,
        right: _isMobile ? 8 : 16,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: buttonSpacing),
            _circleButton(
              icon: _micOn ? Icons.mic : Icons.mic_off,
              color: _micOn
                  ? Theme.of(context).colorScheme.primary
                  : Colors.red,
              onPressed: _hasMicrophone && !_sessionPaused
                  ? () => _applyMicState(!_micOn)
                  : null,
              size: buttonSize,
              iconSize: iconSize,
              tooltip: 'الميكروفون',
            ),
            SizedBox(width: buttonSpacing),
            _circleButton(
              icon: _camOn ? Icons.videocam : Icons.videocam_off,
              color: _camOn
                  ? Theme.of(context).colorScheme.primary
                  : Colors.red,
              onPressed: _hasCamera && !_sessionPaused
                  ? () => _applyCamState(!_camOn)
                  : null,
              size: buttonSize,
              iconSize: iconSize,
              tooltip: 'الكاميرا',
            ),
            SizedBox(width: buttonSpacing),
            _circleButton(
              icon: Icons.cameraswitch,
              color: Theme.of(context).colorScheme.onSurface,
              onPressed:
                  _hasMultipleCameras && _hasCamera && _camOn && !_sessionPaused
                  ? _switchCamera
                  : null,
              size: buttonSize,
              iconSize: iconSize,
              tooltip: 'تبديل الكاميرا',
            ),
            SizedBox(width: buttonSpacing),
            if (_isHosted)
              _circleButton(
                icon: _whiteboardOpen ? Icons.edit_off : Icons.edit,
                color: _whiteboardOpen
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
                onPressed: !_sessionPaused
                    ? _toggleWhiteboard
                    : null,
                size: buttonSize,
                iconSize: iconSize,
                tooltip: 'السبورة',
              ),
            SizedBox(width: buttonSpacing),
            _circleButton(
              icon: Icons.people,
              color: Theme.of(context).colorScheme.onSurface,
              onPressed: _showParticipantsDialog,
              size: buttonSize,
              iconSize: iconSize,
              tooltip: 'المشاركون',
            ),
            SizedBox(width: buttonSpacing),
            AnimatedBuilder(
              animation: _raiseHandAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: (_raisedHands[_selfId] ?? false)
                      ? _raiseHandAnimation.value
                      : 1.0,
                  child: _circleButton(
                    icon: (_raisedHands[_selfId] ?? false)
                        ? Icons.front_hand
                        : Icons.back_hand,
                    color: (_raisedHands[_selfId] ?? false)
                        ? Colors.orange
                        : Theme.of(context).colorScheme.onSurface,
                    onPressed: !_sessionPaused ? _toggleRaiseHand : null,
                    size: buttonSize,
                    iconSize: iconSize,
                    tooltip: 'رفع اليد',
                  ),
                );
              },
            ),
            if (_isCreator) ...[
              SizedBox(width: buttonSpacing),
              _circleButton(
                icon: Icons.meeting_room,
                color: Colors.red,
                onPressed: _stopSession,
                size: buttonSize,
                iconSize: iconSize,
                tooltip: 'إنهاء الاجتماع',
              ),
            ],
            SizedBox(width: buttonSpacing),
          ],
        ),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    required double size,
    required double iconSize,
    String tooltip = '',
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: onPressed == null
                ? Colors.grey[300]
                : Theme.of(context).colorScheme.surfaceContainer,
            shape: BoxShape.circle,
            boxShadow: onPressed != null
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: onPressed == null ? Colors.grey : color,
            size: iconSize,
          ),
        ),
      ),
    );
  }

  void _showParticipantsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final allParticipants = <Map<String, dynamic>>[];
            allParticipants.add({
              'id': _selfId,
              'displayName': '$_displayName (أنت)',
              'photoUrl': _profileImageUrl,
              'isHosted': _isHosted,
              'handRaised': _raisedHands[_selfId] ?? false,
              'micOn': _micOn,
              'camOn': _camOn,
            });
            allParticipants.addAll(_participantsList);

            return Dialog(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('المشاركون', style: TextStyle(fontSize: 20)),
                  ),
                  SizedBox(
                    height: 300,
                    child: ListView.builder(
                      itemCount: allParticipants.length,
                      itemBuilder: (context, index) {
                        final p = allParticipants[index];
                        final isMe = p['id'] == _selfId;
                        final isHosted = _hostedUsers.contains(p['id']) || p['id'] == _teacherId;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: p['photoUrl'] != null ? NetworkImage(p['photoUrl']) : null,
                            child: p['photoUrl'] == null ? Text(p['displayName'][0]) : null,
                          ),
                          title: Text(p['displayName']),
                          subtitle: _isCreator && !isMe
                              ? Row(
                                  children: [
                                    const Text('مضيف: '),
                                    Switch(
                                      value: isHosted,
                                      onChanged: (val) => _toggleHosted(p['id']),
                                    ),
                                  ],
                                )
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isMe)
                                IconButton(
                                  icon: const Icon(Icons.person_add),
                                  onPressed: () => _addFriend(p['id'], p['displayName']),
                                ),
                              if (_isCreator && !isMe) ...[
                                IconButton(
                                  icon: const Icon(Icons.mic_off),
                                  color: Colors.red,
                                  onPressed: () => _muteUser(p['id']),
                                  tooltip: 'كتم الصوت',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.videocam_off),
                                  color: Colors.red,
                                  onPressed: () => _disableUserCamera(p['id']),
                                  tooltip: 'إيقاف الكاميرا',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_off),
                                  color: Colors.orange,
                                  onPressed: () => _disableUserWhiteboard(p['id']),
                                  tooltip: 'منع السبورة',
                                ),
                              ]
                            ],
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _addFriend(String userId, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(name),
        content: const Text('إرسال طلب صداقة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(userId).collection('notifications').add({
                'type': 'friend_request',
                'fromId': currentUser.value!.id,
                'fromName': currentUser.value!.displayName,
                'timestamp': FieldValue.serverTimestamp(),
                'read': false,
              });
              if(mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الإرسال')));
              }
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  Widget _chatDrawer() {
    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(child: Center(child: Text('المحادثة'))),
          Expanded(
            child: ListView.builder(
              controller: _chatScroll,
              itemCount: _chatMessages.length,
              itemBuilder: (context, index) {
                final msg = _chatMessages[index];
                final isMe = msg.uid == _selfId;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMe) Text(msg.from, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                        Text(msg.message),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: const InputDecoration(hintText: 'اكتب رسالة...'),
                    onSubmitted: (val) => _sendChatMessage(val),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendChatMessage(_chatController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          key: _scaffoldKey,
          endDrawer: _chatDrawer(),
          appBar: AppBar(
            title: Text('$_meetingTitle (كود: $_roomCode)'),
            leading: IconButton(
              icon: const Icon(Icons.exit_to_app, color: Colors.red),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.chat),
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: _zoomLayout(context)),
                    if (_whiteboardOpen)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.7),
                          child: _whiteboardScreen(context),
                        ),
                      ),
                    if (_whiteboardOpen)
                      Positioned(top: 70, right: 10, child: _buildDrawingTools()),
                    if (_sessionPaused)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.7),
                          child: const Center(
                            child: Text('الجلسة متوقفة مؤقتاً', style: TextStyle(color: Colors.white, fontSize: 20)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _bottomToolbar(),
            ],
          ),
        ),
      ),
    );
  }
}

class _WhiteboardPainter extends CustomPainter {
  final List<Stroke> strokes;
  final List<WhiteboardText> texts;
  final List<Line> lines;
  final String? selectedTextId;
  final bool isDark;

  _WhiteboardPainter({
    required this.strokes,
    required this.texts,
    required this.lines,
    required this.selectedTextId,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    for (final line in lines) {
      final paint = Paint()
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..strokeWidth = line.width;
      try {
        paint.color = Color(int.parse(line.color.replaceFirst('0x', ''), radix: 16));
      } catch (_) {
        paint.color = Colors.black;
      }
      canvas.drawLine(Offset(line.startX, line.startY), Offset(line.endX, line.endY), paint);
    }

    for (final s in strokes) {
      if (s.points.length < 2) continue;
      final paint = Paint()
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width;
      if (s.isEraser) {
        paint.blendMode = BlendMode.clear;
        paint.strokeWidth = s.width * 2;
      } else {
        try {
          paint.color = Color(int.parse(s.color.replaceFirst('0x', ''), radix: 16));
        } catch (_) {
          paint.color = Colors.black;
        }
        paint.blendMode = BlendMode.srcOver;
      }
      final path = Path();
      path.moveTo((s.points.first['x'] as num).toDouble(), (s.points.first['y'] as num).toDouble());
      for (int i = 1; i < s.points.length; i++) {
        path.lineTo((s.points[i]['x'] as num).toDouble(), (s.points[i]['y'] as num).toDouble());
      }
      canvas.drawPath(path, paint);
    }
    canvas.restore();

    for (final t in texts) {
      canvas.save();
      final center = Offset(t.x + t.text.length * t.fontSize * t.scale / 4, t.y + t.fontSize * t.scale / 2);
      canvas.translate(center.dx, center.dy);
      canvas.rotate(t.rotation * pi / 180);
      canvas.translate(-center.dx, -center.dy);
      final tp = TextPainter(
        text: TextSpan(
          text: t.text,
          style: TextStyle(
            color: Color(int.parse(t.color.replaceFirst('0x', ''), radix: 16)),
            fontSize: t.fontSize * t.scale,
            fontWeight: t.bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.rtl,
      );
      tp.layout();
      tp.paint(canvas, Offset(t.x, t.y));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _PreviewStrokePainter extends CustomPainter {
  final List<Offset> points;
  final double width;
  final Color color;
  final bool isEraser;
  final bool isDark;

  _PreviewStrokePainter({
    required this.points,
    required this.width,
    required this.color,
    required this.isEraser,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    if (isEraser) {
      paint.color = Colors.black.withOpacity(0.3);
      paint.blendMode = BlendMode.dstOut;
      paint.strokeWidth = width * 2;
    } else {
      paint.color = color;
      paint.blendMode = BlendMode.srcOver;
    }
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _PreviewLinePainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final double width;
  final Color color;
  final bool isDark;

  _PreviewLinePainter({
    required this.start,
    required this.end,
    required this.width,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;
    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}