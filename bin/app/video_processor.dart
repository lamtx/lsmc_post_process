import 'dart:async';
import 'dart:io';

import '../misc.dart';
import '../models/app_exception.dart';
import '../models/config.dart';

class Input {
  const Input({
    required this.audioFile,
    required this.videoFile,
    required this.outputFile,
  });

  final File audioFile;
  final File videoFile;
  final File outputFile;
}

class VideoProcessor {
  VideoProcessor(this.config) {
    _listen();
  }

  final _controller = StreamController<Input>();
  final Config config;

  void add(Input input) {
    _controller.add(input);
  }

  void _listen() async {
    await for (final input in _controller.stream) {
      try {
        await _process(input);
      } on Exception catch (e) {
        print(e);
      }
    }
  }

  Future<void> _process(Input input) async {
    if (!Directory(config.outVideosPath).existsSync()) {
      Directory(config.outVideosPath).createSync(recursive: true);
    }

    final tmpDir = Directory.systemTemp.createTempSync();
    final tmpAudioFile = File("${tmpDir.path}/audio-track.opus");
    final tmpVideoFile = File("${tmpDir.path}/video-track.webm");
    try {
      print("processing ${input.videoFile}");
      final r1 = await Process.run(
          config.ppRec, [input.audioFile.path, tmpAudioFile.path]);
      if (r1.exitCode != 0) {
        print(r1.errValue ?? r1.outValue);
        throw const AppException(HttpStatus.badRequest, "Process audio failed");
      }
      final r2 = await Process.run(
          config.ppRec, [input.videoFile.path, tmpVideoFile.path]);
      if (r2.exitCode != 0) {
        print(r2.errValue ?? r2.outValue);
        throw const AppException(HttpStatus.badRequest, "Process video failed");
      }
      final r3 = await Process.run("ffmpeg", [
        "-i",
        tmpAudioFile.path,
        "-i",
        tmpVideoFile.path,
        "-c:v",
        "copy",
        "-c:a",
        "opus",
        "-strict",
        "experimental",
        input.outputFile.path
      ]);
      if (r3.exitCode != 0) {
        print(r3.errValue ?? r3.outValue);
        throw const AppException(
            HttpStatus.badRequest, "Combine audio and video failed");
      }
      _delete(input.audioFile);
      _delete(input.videoFile);
    } finally {
      _delete(tmpDir);
    }
  }

  static void _delete(FileSystemEntity file) {
    try {
      file.deleteSync(recursive: true);
    } on Exception catch (_) {}
  }
}
