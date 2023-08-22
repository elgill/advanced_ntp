part of ntp;

const _defaultLookup = 'time.google.com';

class NTP {
  /// Return NTP delay in milliseconds
  static Future<Map<String, int>> getNtpOffset({
    String lookUpAddress = _defaultLookup,
    int port = 123,
    DateTime? localTime,
    Duration? timeout,
  }) async {
    final List<InternetAddress> addresses =
        await InternetAddress.lookup(lookUpAddress);

    if (addresses.isEmpty) {
      return Future.error('Could not resolve address for $lookUpAddress.');
    }

    final InternetAddress serverAddress = addresses.first;
    InternetAddress clientAddress = InternetAddress.anyIPv4;
    if (serverAddress.type == InternetAddressType.IPv6) {
      clientAddress = InternetAddress.anyIPv6;
    }

    // Init datagram socket to anyIPv4 and to port 0
    final RawDatagramSocket datagramSocket =
        await RawDatagramSocket.bind(clientAddress, 0);

    final _NTPMessage ntpMessage = _NTPMessage();
    final List<int> buffer = ntpMessage.toByteArray();
    final DateTime time = localTime ?? DateTime.now();
    ntpMessage.encodeTimestamp(buffer, 40,
        (time.millisecondsSinceEpoch / 1000.0) + ntpMessage.timeToUtc);

    // Send buffer packet to the address [serverAddress] and port [port]
    datagramSocket.send(buffer, serverAddress, port);
    // Receive packet from socket
    Datagram? packet;

    final receivePacket = (RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        packet = datagramSocket.receive();
      }
      return packet != null;
    };

    try {
      if (timeout != null) {
        await datagramSocket.timeout(timeout).firstWhere(receivePacket);
      } else {
        await datagramSocket.firstWhere(receivePacket);
      }
    } catch (e) {
      rethrow;
    } finally {
      datagramSocket.close();
    }

    if (packet == null) {
      return Future<Map<String, int>>.error('Received empty response.');
    }

    final Map<String, int> result = _parseData(packet!.data, DateTime.now());
    return result;
  }

  /// Get current NTP time
  static Future<DateTime> now({
    String lookUpAddress = _defaultLookup,
    int port = 123,
    Duration? timeout,
  }) async {
    final DateTime localTime = DateTime.now();
    final Map<String, int> offsetData = await getNtpOffset(
      lookUpAddress: lookUpAddress,
      port: port,
      localTime: localTime,
      timeout: timeout,
    );

    return localTime.add(Duration(milliseconds: offsetData['offset']!));
  }

  /// Parse data from datagram socket and calculate precision.
  static Map<String, int> _parseData(List<int> data, DateTime time) {
    final _NTPMessage ntpMessage = _NTPMessage(data);
    final double destinationTimestamp =
        (time.millisecondsSinceEpoch / 1000.0) + 2208988800.0;
    final double localClockOffset =
        ((ntpMessage._receiveTimestamp - ntpMessage._originateTimestamp) +
            (ntpMessage._transmitTimestamp - destinationTimestamp)) /
            2;

    final double delta =
        (destinationTimestamp - ntpMessage._originateTimestamp) -
            (ntpMessage._transmitTimestamp - ntpMessage._receiveTimestamp);

    final double error = delta / 2.0;

    return {
      'offset': (localClockOffset * 1000).toInt(),
      'error': (error * 1000).toInt()
    };
  }
}
