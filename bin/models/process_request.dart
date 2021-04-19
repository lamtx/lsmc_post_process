import 'package:net/net.dart';

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
