import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Opens the gateway socket on Android, iOS and desktop. The Flackle gateway
/// requires the same `Origin` header a browser would send.
WebSocketChannel openGatewaySocket(Uri uri, {required String origin}) =>
    IOWebSocketChannel.connect(
      uri,
      headers: {
        'Origin': origin,
        'User-Agent': 'FlackleMobile/1.0',
      },
      pingInterval: const Duration(seconds: 30),
      connectTimeout: const Duration(seconds: 15),
    );
