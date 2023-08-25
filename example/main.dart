import 'package:advanced_ntp/ntp.dart';

Future<void> main() async {
  [
    'time.google.com',
    'time.facebook.com',
    'time.euro.apple.com',
    'pool.ntp.org',
  ].forEach(_checkTime);
}

Future<void> _checkTime(String lookupAddress) async {
  DateTime _myTime;
  DateTime _ntpTime;

  /// Or you could get NTP current (It will call DateTime.now() and add NTP offset to it)
  _myTime = DateTime.now();

  final NTPResponse ntpResponse =
      await getNtpData(localTime: _myTime, lookUpAddress: lookupAddress);

  /// Or get NTP offset (in milliseconds) and add it yourself
  final int offset = ntpResponse.offset;

  _ntpTime = _myTime.add(Duration(milliseconds: offset));

  print('\n==== $lookupAddress ====');
  print('My time: $_myTime');
  print('NTP time: $_ntpTime');
  print('Difference: ${_myTime.difference(_ntpTime).inMilliseconds}ms');

  return;
}
