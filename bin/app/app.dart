import 'dart:convert';
import 'dart:io';

import 'package:http_server/http_server.dart';
import 'package:net/net.dart';

import '../misc.dart';
import '../models/app_exception.dart';
import '../models/config.dart';
import '../models/error_result.dart';
import '../models/process_request.dart';
import 'video_processor.dart';

class App {
  App() : this._(_loadConfig() ?? Config.defaultConfig);

  App._(this.config) : _processor = VideoProcessor(config) {
    print(config);
  }

  static String _filePrefix(int id) => "videoroom-$id-user-$id-";

  static const _videoPostFix = "-video.mjr";

  static const _audioPostFix = "-audio.mjr";

  final Config config;
  final VideoProcessor _processor;

  Future<void> run() async {
    final staticFiles = VirtualDirectory(config.outDir);
    final requests =
        await HttpServer.bind(InternetAddress.anyIPv4, config.port);
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
          final file = File.fromUri(request.uri);
          staticFiles.serveFile(File(config.outDir + file.path), request);
          break;
      }
    }
  }

  Future<void> _postProcess(Config config, HttpRequest request) async {
    if (request.method != "POST") {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      await request.response.close();
      return;
    }
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
      final audioFile =
          files.firstOrNull((e) => e.path.endsWith(_audioPostFix));
      if (audioFile == null) {
        throw const AppException(HttpStatus.badRequest, "Audio file not found");
      }
      final videoFile =
          files.firstOrNull((e) => e.path.endsWith(_videoPostFix));
      if (videoFile == null) {
        throw const AppException(HttpStatus.badRequest, "Video file not found");
      }
      final outputFile = File("${config.outVideosPath}/${input.id}.webm");
      _processor.add(Input(
        audioFile: audioFile,
        videoFile: videoFile,
        outputFile: outputFile,
      ));
      request.response
        ..statusCode = HttpStatus.ok
        ..write(ErrorResult(message: "Your request is being processed.")
            .serializeAsJson());
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
    }
  }

  static Config? _loadConfig() {
    final file = File("config.json");
    if (file.existsSync()) {
      return Config.parser.parseObject(file.readAsStringSync());
    } else {
      return null;
    }
  }
}
