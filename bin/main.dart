// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A server built using the http_server package that serves the same file for
/// all requests.
/// Visit http://localhost:4046 into your browser.

import 'app/app.dart';
// dart compile exe bin/main.dart -o ~/bin/lsmc-pp
Future<void> main() => App().run();
