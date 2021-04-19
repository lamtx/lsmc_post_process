import 'package:net/net.dart';

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
