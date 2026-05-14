import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_exception.dart';

/// Converte FirebaseException em AppException tipada.
/// Centraliza o tratamento de erros Firestore num só lugar.
AppException mapFirestoreError(Object error, {String recurso = 'Recurso'}) {
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => const PermissionException(),
      'not-found' => NotFoundException(recurso),
      'unavailable' || 'deadline-exceeded' => const NetworkException(),
      'cancelled' || 'unauthenticated' => const AuthException(),
      _ => const ServerException(),
    };
  }
  return const ServerException();
}
