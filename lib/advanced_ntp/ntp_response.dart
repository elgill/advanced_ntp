part of advanced_ntp;

class NTPResponse {
  NTPResponse({
    required this.dateTime,
    required this.offset,
    required this.roundTripDelay,
    required this.lookupServer,
    required this.stratum,
  });

  final DateTime dateTime;
  final int offset;
  final int roundTripDelay;
  final String lookupServer;
  final int stratum;
}
