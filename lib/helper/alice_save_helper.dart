import 'dart:convert';
import 'dart:io';

import 'package:alice/model/alice_http_call.dart';
import 'package:alice/ui/utils/alice_parser.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info/package_info.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share/share.dart';

import '../helper/alice_alert_helper.dart';

class AliceSaveHelper {
  static JsonEncoder _encoder = new JsonEncoder.withIndent('  ');

  /// Top level method used to save calls to file
  static void saveCalls(
      BuildContext context, List<AliceHttpCall> calls, Brightness brightness) {
    assert(context != null, "context can't be null");
    assert(calls != null, "calls can't be null");
    assert(brightness != null, "brightness can't be null");
    _checkPermissions(context, calls, brightness);
  }

  static void _checkPermissions(BuildContext context, List<AliceHttpCall> calls,
      Brightness brightness) async {
    assert(context != null, "context can't be null");
    assert(calls != null, "calls can't be null");
    assert(brightness != null, "brightness can't be null");
    var status = await Permission.storage.status;
    if (status.isGranted) {
      _saveToFile(context, calls, brightness);
    } else {
      var status = await Permission.storage.request();

      if (status.isGranted) {
        _saveToFile(context, calls, brightness);
      } else {
        AliceAlertHelper.showAlert(context, "Permission error",
            "Permission not granted. Couldn't save logs.",
            brightness: brightness);
      }
    }
  }

  static Future<String> _saveToFile(BuildContext context,
      List<AliceHttpCall> calls, Brightness brightness) async {
    assert(context != null, "context can't be null");
    assert(calls != null, "calls can't be null");
    assert(brightness != null, "brightness can't be null");
    try {
      if (calls.length == 0) {
        AliceAlertHelper.showAlert(
            context, "Error", "There are no logs to save",
            brightness: brightness);
        return "";
      }
      bool isAndroid = Platform.isAndroid;

      Directory externalDir = await (isAndroid
          ? getExternalStorageDirectory()
          : getApplicationDocumentsDirectory());

      String fileName =
          "alice_log_${DateTime.now().millisecondsSinceEpoch}.json";

      File file = File(externalDir.path.toString() + "/" + fileName);
      file.createSync();

      IOSink sink = file.openWrite(mode: FileMode.append);

      final Map<String, dynamic> map = {
        'general_info': null,
        'log': {},
        'reversed_log': {},
      };

      final aliceLog = await _buildAliceLog();

      map['general_info'] = aliceLog;

      calls.forEach((AliceHttpCall call) {
        map['log']['${call.response.status} ${call.endpoint}'] =
            _buildCallLog(call);
      });

      calls.reversed.forEach((AliceHttpCall call) {
        map['reversed_log']['${call.response.status} ${call.endpoint}'] =
            _buildCallLog(call);
      });

      sink.write(JsonEncoder().convert(map));

      await sink.flush();
      await sink.close();

      AliceAlertHelper.showAlert(
          context, "Success", "Sucessfully saved logs in ${file.path}",
          secondButtonTitle: isAndroid ? "View file" : null,
          secondButtonAction: () => isAndroid ? OpenFile.open(file.path) : null,
          brightness: brightness);

      Share.share(JsonEncoder().convert(map), subject: 'Request List');

      return file.path;
    } catch (exception) {
      AliceAlertHelper.showAlert(
          context, "Error", "Failed to save http calls to file",
          brightness: brightness);
      print(exception);
    }

    return "";
  }

  static Future<Map<String, dynamic>> _buildAliceLog() async {
    var packageInfo = await PackageInfo.fromPlatform();
    Map<String, dynamic> map = {};
    map['title'] = "Alice - HTTP Inspector";
    map['app_name'] = packageInfo.appName;
    map['package_name'] = packageInfo.packageName;
    map['version'] = packageInfo.version;
    map['build_number'] = packageInfo.buildNumber;
    map['createdAt'] = DateTime.now().toIso8601String();
    return map;
  }

  static Map<String, dynamic> _buildCallLog(AliceHttpCall call) {
    assert(call != null, "call can't be null");
    Map<String, dynamic> map = {
      'traceId': '${call.traceId}',
      'url': '${call.method} https://${call.server}${call.endpoint}',
      'responseCode': '${call.response.status}',
      'request': null,
      'response': null,
    };

    try {
      map['request'] = JsonDecoder().convert(
          '${AliceParser.formatBody(call.request.body, AliceParser.getContentType(call.request.headers))}');
    } catch (e) {
      map['request'] =
          '${AliceParser.formatBody(call.request.body, AliceParser.getContentType(call.request.headers))}';
    }

    try {
      map['response'] = JsonDecoder().convert(
          '${AliceParser.formatBody(call.response.body, AliceParser.getContentType(call.response.headers))}');
    } catch (e) {
      map['response'] =
          '${AliceParser.formatBody(call.response.body, AliceParser.getContentType(call.response.headers))}';
    }

    if (call.error != null) {
      map['error'] = {
        'error': '${call.error.error}',
        'stackTrace': '${call.error.stackTrace}',
      };
    }

    return map;
  }

  static Future<Map<String, dynamic>> buildCallLog(AliceHttpCall call) async {
    assert(call != null, "call can't be null");
    try {
      final aliceLog = await _buildAliceLog();
      final callLog = _buildCallLog(call);
      return {
        'general_info': aliceLog,
        'log': callLog,
      };
    } catch (exception) {
      return {'error': "Failed to generate call log"};
    }
  }
}
