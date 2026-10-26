import 'package:web_socket_channel/web_socket_channel.dart';

/// Browsers own the `Origin` header and reject attempts to set it, so the web
/// client connects directly and lets the browser supply the handshake origin.
WebSocketChannel openGatewaySocket(Uri uri, {required String origin}) =>
    WebSocketChannel.connect(uri);
