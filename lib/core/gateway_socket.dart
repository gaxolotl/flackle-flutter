// Flackle's gateway rejects handshakes without a browser Origin header. Native
// clients have to set it themselves; browsers set it automatically.
export 'gateway_socket_io.dart'
    if (dart.library.html) 'gateway_socket_web.dart';
