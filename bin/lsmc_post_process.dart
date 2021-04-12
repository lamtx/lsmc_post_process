// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A server built using the http_server package that serves the same file for
/// all requests.
/// Visit http://localhost:4046 into your browser.
// #docregion
import 'dart:convert';
import 'dart:io';
import 'package:http_server/http_server.dart';
import 'package:net/net.dart';

Future<void> main() async {
  final config = _loadConfig() ?? Config.defaultConfig;
  final staticFiles = VirtualDirectory(config.outDir);

  final requests = await HttpServer.bind(InternetAddress.anyIPv4, config.port);
  final ips = await NetworkInterface.list();
  print(
      "service started at: http://${ips.first.addresses.firstWhere((element) => element.type == InternetAddressType.IPv4).address}:${config.port}");
  await for (final request in requests) {
    print("${request.method}: ${request.uri}");
    switch (request.uri.pathSegments.firstOrNull()) {
      case "process":
        await _postProcess(config, request);
        break;
      default:
        staticFiles.serveFile(File(request.uri.path), request);
        break;
    }
  }
}

Config? _loadConfig() {
  final file = File("config.json");
  if (file.existsSync()) {
    return Config.parser.parseObject(file.readAsStringSync());
  } else {
    return null;
  }
}

String _filePrefix(int id) => "videoroom-$id-user-$id-";

String get _videoPostFix => "-video.mjr";

String get _audioPostFix => "-audio.mjr";

extension<T> on Iterable<T> {
  T? firstOrNull([bool Function(T e)? predicate]) {
    if (predicate == null) {
      return isEmpty ? null : first;
    } else {
      for (final e in this) {
        if (predicate(e)) {
          return e;
        }
      }
      return null;
    }
  }
}

Future<void> _postProcess(Config config, HttpRequest request) async {
  if (request.method != "POST") {
    request.response.statusCode = HttpStatus.methodNotAllowed;
    await request.response.close();
    return;
  }
  Directory? tmpDir;
  try {
    final content = await utf8.decoder.bind(request).join();
    final input = ProcessRequest.parser.parseObject(content);
    if (input.id <= 0) {
      throw const AppException(HttpStatus.badRequest, "id is required.");
    }
    if (input.path.isEmpty) {
      throw const AppException(HttpStatus.badRequest, "path is required.");
    }
    final dir = Directory(input.path);
    if (!dir.existsSync()) {
      throw const AppException(
          HttpStatus.badRequest, "The given path not found.");
    }
    final prefix = _filePrefix(input.id);
    final files = dir
        .listSync(followLinks: false)
        .whereType<File>()
        .where((element) => element.name.startsWith(prefix));
    final audioFile = files.firstOrNull((e) => e.path.endsWith(_audioPostFix));
    if (audioFile == null) {
      throw const AppException(HttpStatus.badRequest, "Audio file not found");
    }
    final videoFile = files.firstOrNull((e) => e.path.endsWith(_videoPostFix));
    if (videoFile == null) {
      throw const AppException(HttpStatus.badRequest, "Video file not found");
    }
    tmpDir = Directory.systemTemp.createTempSync();
    final tmpAudioFile = File("${tmpDir.path}/audio-track.opus");
    final tmpVideoFile = File("${tmpDir.path}/video-track.webm");
    final outFile = File("${config.outVideosPath}/${input.id}.webm");
    if (!Directory(config.outVideosPath).existsSync()) {
      Directory(config.outVideosPath).createSync(recursive: true);
    }
    final r1 =
        await Process.run(config.ppRec, [audioFile.path, tmpAudioFile.path]);
    if (r1.exitCode != 0) {
      print(r1.errValue ?? r1.outValue);
      throw const AppException(HttpStatus.badRequest, "Process audio failed");
    }
    final r2 =
        await Process.run(config.ppRec, [videoFile.path, tmpVideoFile.path]);
    if (r2.exitCode != 0) {
      print(r2.errValue ?? r2.outValue);
      throw const AppException(HttpStatus.badRequest, "Process video failed");
    }
    final r3 = await Process.run("ffmpeg", [
      "-i ${tmpAudioFile.path} -i ${tmpVideoFile.path}  -c:v copy -c:a opus -strict experimental ${outFile.path}"
    ]);
    if (r3.exitCode != 0) {
      print(r3.errValue ?? r3.outValue);
      throw const AppException(
          HttpStatus.badRequest, "Combine audio and video failed");
    }
    request.response
      ..statusCode = HttpStatus.ok
      ..write(ErrorResult(message: outFile.path).serializeAsJson());
    await request.response.close();
  } on AppException catch (e) {
    request.response
      ..statusCode = e.httpStatusCode
      ..write(ErrorResult(message: e.message).serializeAsJson());
    await request.response.close();
  } on Exception catch (e) {
    request.response
      ..statusCode = HttpStatus.internalServerError
      ..write(ErrorResult(message: e.toString()).serializeAsJson());
    await request.response.close();
  } finally {
    if (tmpDir != null) {
      final _ = tmpDir.delete(recursive: true);
    }
  }
}

class Config {
  const Config({
    required this.port,
    required this.outDir,
    required this.janusDir,
  });

  final int port;
  final String outDir;
  final String janusDir;

  static const defaultConfig = Config(
    port: 4046,
    outDir: "/home/ubuntu/lsmc_post_process",
    janusDir: "/opt/janus",
  );

  String get ppRec => "$janusDir/bin/janus-pp-rec";

  String get outVideosPath => "$outDir/videos";

  static final DataParser<Config> parser = (reader) => Config(
        port: reader.readNullableInt("port") ?? defaultConfig.port,
        outDir: reader.readString("outDir", defaultConfig.outDir),
        janusDir: reader.readString("janusDir", defaultConfig.janusDir),
      );
}

class ProcessRequest {
  ProcessRequest({
    required this.id,
    required this.path,
  });

  final int id;
  final String path;
  static final DataParser<ProcessRequest> parser = (reader) => ProcessRequest(
        id: reader.readInt("id"),
        path: reader.readString("path"),
      );
}

class ErrorResult implements JsonObject {
  ErrorResult({
    required this.message,
  });

  final String message;

  @override
  Object describeContent() => {
        "message": message,
      };
}

class AppException implements Exception {
  const AppException(this.httpStatusCode, this.message);

  final int httpStatusCode;
  final String message;

  @override
  String toString() => message;
}

extension on File {
  String get name {
    final i = path.lastIndexOf(Platform.pathSeparator);
    return i == -1 ? path : path.substring(i + 1);
  }
}

extension on ProcessResult {
  String? get outValue => this.stdout as String?;

  String? get errValue => this.stderr as String?;
}
