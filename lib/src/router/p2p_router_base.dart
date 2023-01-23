part of 'router.dart';

abstract class P2PRouterBase {
  static const defaultPort = 2022;
  static const defaultPeriod = Duration(seconds: 1);
  static const defaultTimeout = Duration(seconds: 3);

  // TBD: decide where to remove stale routes
  final Map<P2PPeerId, P2PRoute> routes = {};
  final Iterable<P2PTransportBase> transports;
  final P2PCrypto crypto;

  var transportTTL = defaultTimeout.inSeconds;
  void Function(String)? logger;

  late final P2PPeerId _selfId;

  var _isRun = false;

  bool get isRun => _isRun;
  bool get isNotRun => !_isRun;
  P2PPeerId get selfId => _selfId;

  P2PRouterBase({
    final P2PCrypto? crypto,
    final Iterable<P2PTransportBase>? transports,
    this.logger,
  })  : crypto = crypto ?? P2PCrypto(),
        transports = transports ??
            [
              P2PUdpTransport(
                  fullAddress: P2PFullAddress(
                address: InternetAddress.anyIPv4,
                isLocal: false,
                port: defaultPort,
              )),
              P2PUdpTransport(
                  fullAddress: P2PFullAddress(
                address: InternetAddress.anyIPv6,
                isLocal: false,
                port: defaultPort,
              )),
            ];

  Future<P2PCryptoKeys> init([P2PCryptoKeys? keys]) async {
    final cryptoKeys = await crypto.init(keys);
    _selfId = P2PPeerId.fromKeys(
      encryptionKey: cryptoKeys.encPublicKey,
      signKey: cryptoKeys.signPublicKey,
    );
    return cryptoKeys;
  }

  Future<void> start() async {
    if (_isRun) return;
    logger?.call('Start listen $transports with key $_selfId');
    if (transports.isEmpty) {
      throw Exception('Need at least one P2PTransport!');
    }
    for (final t in transports) {
      t.ttl = transportTTL;
      t.callback = onMessage;
      await t.start();
    }
    _isRun = true;
  }

  void stop() {
    _isRun = false;
    for (final t in transports) {
      t.stop();
    }
  }

  void sendDatagram({
    required final Iterable<P2PFullAddress> addresses,
    required final Uint8List datagram,
  }) {
    for (final t in transports) {
      t.send(addresses, datagram);
    }
  }

  /// returns null if message is processed and children have to return
  Future<P2PPacket?> onMessage(final P2PPacket packet);
}
