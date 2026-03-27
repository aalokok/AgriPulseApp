import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../services/farmos_client.dart';
import '../services/animal_service.dart';
import '../services/water_level_service.dart';

// ── Core service singletons ─────────────────────────────────────────────

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final farmosClientProvider = Provider<FarmosClient>((ref) {
  return FarmosClient(ref.read(authServiceProvider));
});

final animalServiceProvider = Provider<AnimalService>((ref) {
  return AnimalService(ref.read(farmosClientProvider));
});

final waterLevelServiceProvider = Provider<WaterLevelService>((ref) {
  return WaterLevelService(ref.read(farmosClientProvider));
});

// ── Auth state ──────────────────────────────────────────────────────────

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final String? serverUrl;
  final String? errorMessage;
  final bool isLoading;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.serverUrl,
    this.errorMessage,
    this.isLoading = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? serverUrl,
    String? errorMessage,
    bool? isLoading,
  }) {
    return AuthState(
      status: status ?? this.status,
      serverUrl: serverUrl ?? this.serverUrl,
      errorMessage: errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  AuthService get _authService => ref.read(authServiceProvider);

  Future<void> tryRestoreSession() async {
    final restored = await _authService.tryRestoreSession();
    if (restored) {
      state = AuthState(
        status: AuthStatus.authenticated,
        serverUrl: _authService.serverUrl,
      );
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _authService.login(
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        serverUrl: _authService.serverUrl,
      );
    } on DioException catch (e) {
      final message = switch (e.response?.statusCode) {
        400 => 'Invalid credentials. Please check your username and password.',
        401 => 'Authentication failed. Please check your credentials.',
        _ => e.response?.statusCode != null
            ? 'Server error (${e.response!.statusCode}). Please try again.'
            : 'Could not connect to server. Please check the URL.',
      };
      state = state.copyWith(
        isLoading: false,
        errorMessage: message,
        status: AuthStatus.unauthenticated,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Connection failed: ${e.toString()}',
        status: AuthStatus.unauthenticated,
      );
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
