import 'package:net/net.dart';

class Config {
  const Config({
    required this.port,
    required this.outDir,
    required this.janusDir,
  });

  @override
  String toString() =>
      'Config{port: $port, outDir: $outDir, janusDir: $janusDir}';

  final int port;
  final String outDir;
  final String janusDir;

  static const defaultConfig = Config(
    port: 4046,
    outDir: "/home/may/lsmc_post_process",
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
