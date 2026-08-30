import 'runtime_link_base.dart';

import 'runtime_link_stub.dart'
    if (dart.library.io) 'runtime_link_io.dart' as impl;

export 'runtime_link_base.dart';

RuntimeLink createRuntimeLink() => impl.createRuntimeLinkImpl();