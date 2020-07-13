import 'package:flutter/foundation.dart';
import 'package:freibad_app/models/session.dart';

class Appointment extends Session {
  Appointment({
    @required String id,

    ///following this scheme [{'person': 'personId', 'code': 'accessCode'}]
    @required List<Map<String, String>> accessList,
    @required DateTime startTime,
    @required DateTime endTime,
  }) : super(
          id: id,
          accessList: accessList,
          startTime: startTime,
          endTime: endTime,
        );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'accessList': accessListToString(accessList),
    };
  }

  static List<Map<String, String>> stringToAccessList(
      String encodedAccessList) {
    List<String> tempSeparation = encodedAccessList
        .split(";"); //person string and code string are seperated by ';'

    List<Map<String, String>> accessList =
        Session.stringToAccessList(tempSeparation[0]);

    List<String> codes = tempSeparation[1].split(',');

    for (int i = 0; i < accessList.length; i++) {
      accessList.add({'code': codes[i]});
    }

    return accessList;
  }

  @override
  String accessListToString(List<Map<String, String>> accessList) {
    String encodedAccessList =
        super.accessListToString(accessList); //add persons

    encodedAccessList += ';';

    for (Map<String, String> access in accessList) {
      encodedAccessList += access['code'] + ',';
    }

    return encodedAccessList;
  }
}