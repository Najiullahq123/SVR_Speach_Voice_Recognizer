library default_connector;

import 'package:cloud_firestore/cloud_firestore.dart';

class DefaultConnector {
  static const String region = 'us-central1';
  static const String projectId = 'svrapp';

  final FirebaseFirestore firestore;

  DefaultConnector._({required this.firestore});

  static DefaultConnector? _instance;

  static DefaultConnector get instance {
    _instance ??= DefaultConnector._(firestore: FirebaseFirestore.instance);
    return _instance!;
  }

  Future<void> useEmulator(String host, int port) async {
    FirebaseFirestore.instance.useFirestoreEmulator(host, port);
  }
}
