import 'dart:convert';
import 'dart:io';

import 'package:alice/model/alice_http_call.dart';
import 'package:alice/ui/utils/alice_parser.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info/package_info.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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
        'log': [],
      };
      final aliceLog = await _buildAliceLog();
      map['general_info'] = aliceLog;
      calls.forEach((AliceHttpCall call) {
        map['log'].add(_buildCallLog(call));
      });
      // sink.write(await _buildAliceLog());
      // calls.forEach((AliceHttpCall call) {
      //   sink.write(_buildCallLog(call));
      // });
      sink.write(JsonEncoder().convert(map));
      await sink.flush();
      await sink.close();
      AliceAlertHelper.showAlert(
          context, "Success", "Sucessfully saved logs in ${file.path}",
          secondButtonTitle: isAndroid ? "View file" : null,
          secondButtonAction: () => isAndroid ? OpenFile.open(file.path) : null,
          brightness: brightness);
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
    // StringBuffer stringBuffer = StringBuffer();
    var packageInfo = await PackageInfo.fromPlatform();
    Map<String, dynamic> map = {};
    // stringBuffer.write("Alice - HTTP Inspector\n");
    map['title'] = "Alice - HTTP Inspector";
    // stringBuffer.write("App name:  ${packageInfo.appName}\n");
    map['app_name'] = packageInfo.appName;
    // stringBuffer.write("Package: ${packageInfo.packageName}\n");
    map['package_name'] = packageInfo.packageName;
    // stringBuffer.write("Version: ${packageInfo.version}\n");
    map['version'] = packageInfo.version;
    // stringBuffer.write("Build number: ${packageInfo.buildNumber}\n");
    map['build_number'] = packageInfo.buildNumber;
    // stringBuffer.write("Generated: " + DateTime.now().toIso8601String() + "\n");
    map['createdAt'] = DateTime.now().toIso8601String();
    // stringBuffer.write("\n");
    return map;
  }

  static Map<String, dynamic> _buildCallLog(AliceHttpCall call) {
    assert(call != null, "call can't be null");
    StringBuffer stringBuffer = StringBuffer();
    Map<String, dynamic> map = {
      'general_data': null,
      'request': null,
      'response': null,
      'error': null,
    };
    // stringBuffer.write("===========================================\n");
    // stringBuffer.write("Id: ${call.id}\n");
    // stringBuffer.write("============================================\n");
    map['general_data'] = {
      'traceId': '${call.traceId}',
      'url': '${call.method} https://${call.server}${call.endpoint}',
      'responseCode': '${call.response.status}',
    };

    // stringBuffer.write("===========================================\n");
    // stringBuffer.write("General data\n");
    // stringBuffer.write("===========================================\n");
    // stringBuffer.write("TraceId: ${call.traceId} \n");
    // stringBuffer
    //     .write("Url: ${call.method} https://${call.server}${call.endpoint}\n");
    // stringBuffer.write("ResponseCode: ${call.response.status} \n");

    //// stringBuffer.write("Client: ${call.client} \n");
    //// stringBuffer
    ////     .write("Duration ${AliceConversionHelper.formatTime(call.duration)}\n");
    //// stringBuffer.write("Secured connection: ${call.secure}\n");
    //// stringBuffer.write("Completed: ${!call.loading} \n");
    map['request'] =
        '${AliceParser.formatBody(call.request.body, AliceParser.getContentType(call.request.headers))}';
    map['response'] =
        '${AliceParser.formatBody(call.response.body, AliceParser.getContentType(call.response.headers))}';

    // stringBuffer.write("--------------------------------------------\n");
    // stringBuffer.write("Request Body\n");
    // stringBuffer.write("--------------------------------------------\n");

    // stringBuffer.write("Request time: ${call.request.time}\n");
    // stringBuffer.write("Request content type: ${call.request.contentType}\n");
    // stringBuffer
    //     .write("Request cookies: ${_encoder.convert(call.request.cookies)}\n");
    // stringBuffer
    //     .write("Request headers: ${_encoder.convert(call.request.headers)}\n");
    // stringBuffer.write(
    //     "Request size: ${AliceConversionHelper.formatBytes(call.request.size)}\n");

    // stringBuffer.write(
    //     "${AliceParser.formatBody(call.request.body, AliceParser.getContentType(call.request.headers))}\n");
    // stringBuffer.write("--------------------------------------------\n");
    // stringBuffer.write("Response Body\n");
    // stringBuffer.write("--------------------------------------------\n");

    // stringBuffer.write("Response time: ${call.response.time}\n");
    // stringBuffer.write("Response status: ${call.response.status}\n");
    // stringBuffer.write(
    //     "Response size: ${AliceConversionHelper.formatBytes(call.response.size)}\n");
    // stringBuffer.write(
    //     "Response headers: ${_encoder.convert(call.response.headers)}\n");

    // stringBuffer.write(
    //     "${AliceParser.formatBody(call.response.body, AliceParser.getContentType(call.response.headers))}\n");

    if (call.error != null) {
      map['error'] = {
        'error': '${call.error.error}',
        'stackTrace': '${call.error.stackTrace}',
      };
      // stringBuffer.write("--------------------------------------------\n");
      // stringBuffer.write("Error\n");
      // stringBuffer.write("--------------------------------------------\n");
      // stringBuffer.write("Error: ${call.error.error}\n");
      // if (call.error.stackTrace != null) {
      //   stringBuffer.write("Error stacktrace: ${call.error.stackTrace}\n");
      // }
    }
    // stringBuffer.write("--------------------------------------------\n");
    // stringBuffer.write("Curl\n");
    // stringBuffer.write("--------------------------------------------\n");
    // stringBuffer.write("${call.getCurlCommand()}");
    // stringBuffer.write("\n");
    // stringBuffer.write("==============================================\n");
    // stringBuffer.write("\n");

    // return stringBuffer.toString();
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
