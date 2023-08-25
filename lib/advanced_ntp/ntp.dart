part of advanced_ntp;

const _defaultLookup = 'time.google.com';

Future<NTPMessage> _getRawNtpMessage({
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

  final NTPMessage senderNtpMessage = NTPMessage();
  final List<int> buffer = senderNtpMessage.toByteArray();
  final DateTime time = localTime ?? DateTime.now();
  senderNtpMessage.encodeTimestamp(buffer, 40,
      (time.millisecondsSinceEpoch / 1000.0) + senderNtpMessage.timeToUtc);

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
    return Future<NTPMessage>.error('Received empty response.');
  }

  final NTPMessage receivedNtpMessage = NTPMessage(packet!.data);
  return receivedNtpMessage;
}

Future<NTPResponse> getNtpData({
  String lookUpAddress = _defaultLookup,
  int port = 123,
  DateTime? localTime,
  Duration? timeout,
}) async {
  final NTPMessage receivedNtpMessage = await _getRawNtpMessage(
    lookUpAddress: lookUpAddress,
    port: port,
    localTime: localTime,
    timeout: timeout,
  );
  final double receivedTimestamp =
      (DateTime.now().millisecondsSinceEpoch / 1000.0) + 2208988800.0;

  final int offset = _parseOffset(receivedNtpMessage, receivedTimestamp);
  final int roundTripDelay =
    _calculateRTT(receivedNtpMessage, receivedTimestamp);

  return NTPResponse(
    dateTime: DateTime.now().add(Duration(milliseconds: offset)),
    offset: offset,
    roundTripDelay: roundTripDelay,
    lookupServer: lookUpAddress,
    stratum: receivedNtpMessage._stratum,
  );
}

Future<DateTime> now({
  String lookUpAddress = _defaultLookup,
  int port = 123,
  Duration? timeout,
}) async {
  final NTPResponse ntpData = await getNtpData(
    lookUpAddress: lookUpAddress,
    port: port,
    timeout: timeout,
  );
  return ntpData.dateTime;
}

/// Parse data from datagram socket and calculate precision.
int _parseOffset(NTPMessage ntpMessage, double destinationTimestamp) {
  final double localClockOffset =
      ((ntpMessage._receiveTimestamp - ntpMessage._originateTimestamp) +
          (ntpMessage._transmitTimestamp - destinationTimestamp)) /
          2;

  return (localClockOffset * 1000).toInt();
}

int _calculateRTT(NTPMessage message, double clientReceiveTimestamp) {
  final double t1 = message.originateTimestamp;
  final double t2 = message.receiveTimestamp;
  final double t3 = message.transmitTimestamp;
  final double t4 = clientReceiveTimestamp;

  final double rtt = (t4 - t1) - (t3 - t2);
  return (rtt * 1000).toInt();
}

