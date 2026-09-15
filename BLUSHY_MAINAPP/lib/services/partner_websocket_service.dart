import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_base_url.dart';
import 'auth_storage.dart';

class PartnerWebSocketEvent {
  final String event;
  final String? userId;
  final String? reason;
  final String? connectionId;
  final String? invitationId;
  final String? messageId;
  final Map<String, dynamic> rawPayload;

  const PartnerWebSocketEvent({
    required this.event,
    this.userId,
    this.reason,
    this.connectionId,
    this.invitationId,
    this.messageId,
    required this.rawPayload,
  });

  factory PartnerWebSocketEvent.fromJson(Map<String, dynamic> json) {
    final payload = (json['payload'] is Map<String, dynamic>)
        ? json['payload'] as Map<String, dynamic>
        : <String, dynamic>{};

    return PartnerWebSocketEvent(
      event: json['event']?.toString() ?? '',
      userId: json['userId']?.toString(),
      reason: payload['reason']?.toString(),
      connectionId: payload['connectionId']?.toString(),
      invitationId: payload['invitationId']?.toString(),
      messageId: payload['messageId']?.toString() ?? payload['message_id']?.toString(),
      rawPayload: payload,
    );
  }
}

class PartnerWebSocketService {
  static final PartnerWebSocketService _instance = PartnerWebSocketService._internal();
  factory PartnerWebSocketService() => _instance;
  PartnerWebSocketService._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  final _eventController = StreamController<PartnerWebSocketEvent>.broadcast();

  bool _isConnecting = false;
  bool _isDisposed = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  final Set<String> _seenMessageIds = {};

  Stream<PartnerWebSocketEvent> get events => _eventController.stream;

  bool get isConnected => _channel != null;

  Uri _buildWebSocketUri(String token) {
    final base = resolveApiBaseUrl();
    final parsed = Uri.parse(base);
    final scheme = parsed.scheme == 'https' ? 'wss' : 'ws';
    final host = parsed.host;
    final port = parsed.hasPort ? parsed.port : (scheme == 'wss' ? 443 : 80);

    return Uri(
      scheme: scheme,
      host: host,
      port: port != 80 && port != 443 ? port : null,
      path: '/ws',
      queryParameters: {'token': token},
    );
  }

  void connect() {
    if (_isDisposed || _isConnecting || _channel != null) return;

    final token = AuthStorage.getToken();
    if (token == null || token.isEmpty) {
      return;
    }

    _isConnecting = true;

    try {
      final wsUri = _buildWebSocketUri(token);
      final redactedUri = '${wsUri.scheme}://${wsUri.host}${wsUri.hasPort ? ':${wsUri.port}' : ''}${wsUri.path}?token=[REDACTED]';
      debugPrint('PartnerWS: Connecting to $redactedUri');

      final channel = WebSocketChannel.connect(wsUri);
      _channel = channel;

      // `connect` is lazy: it returns a channel before the socket exists, and
      // reports failure on `ready` as well as on the stream. Nothing awaited
      // `ready`, so a refused connection became an unhandled exception on
      // every retry -- the error the logs were full of.
      unawaited(channel.ready.then((_) {
        // Only a real connection clears the backoff. Resetting right after
        // `connect` meant every failure started from zero, so the delay never
        // grew past two seconds and the retry ran forever at that rate.
        _reconnectAttempts = 0;
        debugPrint('PartnerWS: Connected.');
      }).catchError((Object error) {
        debugPrint('PartnerWS: Connect failed: $error');
        _scheduleReconnect();
      }));

      _channelSubscription = channel.stream.listen(
        (message) {
          _handleIncomingMessage(message);
        },
        onError: (error) {
          // `ready` already reports the failure that ends a connection attempt;
          // scheduling from both paths would double the retry rate.
          debugPrint('PartnerWS: Stream error: $error');
        },
        onDone: () {
          debugPrint('PartnerWS: Connection closed.');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );

      _isConnecting = false;
    } catch (e) {
      debugPrint('PartnerWS: Connect failed: $e');
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  void _handleIncomingMessage(dynamic raw) {
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is Map<String, dynamic>) {
        final event = PartnerWebSocketEvent.fromJson(decoded);

        // Deduplication check for message IDs
        if (event.messageId != null && event.messageId!.isNotEmpty) {
          if (_seenMessageIds.contains(event.messageId)) {
            return;
          }
          if (_seenMessageIds.length > 200) {
            _seenMessageIds.clear();
          }
          _seenMessageIds.add(event.messageId!);
        }

        _eventController.add(event);
      }
    } catch (e) {
      debugPrint('PartnerWS: Message parse error: $e');
    }
  }

  void _scheduleReconnect() {
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel = null;
    _isConnecting = false;

    if (_isDisposed) return;

    // A single attempt can fail on `ready` and then again on `onDone`; without
    // this the two paths would stack timers and retry twice as fast.
    if (_reconnectTimer?.isActive ?? false) return;

    _reconnectTimer?.cancel();
    _reconnectAttempts++;

    final backoffSec = math.min(30, math.pow(2, math.min(_reconnectAttempts, 5)).toInt());
    final jitterMs = math.Random().nextInt(1000);
    final delay = Duration(seconds: backoffSec, milliseconds: jitterMs);

    debugPrint('PartnerWS: Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)');
    _reconnectTimer = Timer(delay, () {
      if (!_isDisposed) {
        connect();
      }
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel?.sink.close();
    _channel = null;
    _isConnecting = false;
  }

  void dispose() {
    _isDisposed = true;
    disconnect();
    _eventController.close();
  }
}
