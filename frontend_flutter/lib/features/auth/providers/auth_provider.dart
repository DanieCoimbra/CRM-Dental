import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend_flutter/features/auth/data/auth_repository.dart';
import 'package:frontend_flutter/features/settings/data/user_model.dart';
import 'package:frontend_flutter/features/settings/data/clinic_model.dart';
import 'package:frontend_flutter/core/network/api_client.dart';

const _storage = FlutterSecureStorage();

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String role; // 'admin', 'doctor', 'receptionist'
  
  AuthState({
    required this.isLoading,
    required this.isAuthenticated,
    this.role = 'admin',
  });
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _checkAuth();
    return AuthState(isLoading: true, isAuthenticated: false);
  }

  Future<void> _checkAuth() async {
    final token = await _storage.read(key: 'jwt_token');
    AuthTokenHolder.token = token;
    final role = await _storage.read(key: 'user_role') ?? 'admin';
    state = AuthState(isLoading: false, isAuthenticated: token != null, role: role);
  }

  Future<void> login(String email, String password) async {
    final repository = ref.read(authRepositoryProvider);
    final data = await repository.login(email: email, password: password);
    
    final token = data['token'];
    final user = data['user'];
    if (token != null) {
      final role = user['role']?.toString().toUpperCase() ?? 'ADMIN';
      AuthTokenHolder.token = token.toString();
      await _storage.write(key: 'jwt_token', value: token.toString());
      await _storage.write(key: 'user_role', value: role); 
      ref.invalidate(currentClinicProvider);
      ref.invalidate(currentUserProvider);
      state = AuthState(isLoading: false, isAuthenticated: true, role: role);
    }
  }

  Future<void> registerClinic({
    required String clinicName,
    required String clinicEmail,
    required String adminName,
    required String adminEmail,
    required String password,
  }) async {
    final repository = ref.read(authRepositoryProvider);
    final data = await repository.registerClinic(
      clinicName: clinicName,
      clinicEmail: clinicEmail,
      adminName: adminName,
      adminEmail: adminEmail,
      password: password,
    );
    
    final token = data['token'];
    final user = data['user'];
    if (token != null) {
      final role = user['role']?.toString().toUpperCase() ?? 'ADMIN';
      AuthTokenHolder.token = token.toString();
      await _storage.write(key: 'jwt_token', value: token.toString());
      await _storage.write(key: 'user_role', value: role); 
      ref.invalidate(currentClinicProvider);
      ref.invalidate(currentUserProvider);
      state = AuthState(isLoading: false, isAuthenticated: true, role: role);
    }
  }

  Future<void> switchRole(String newRole) async {
    await _storage.write(key: 'user_role', value: newRole);
    state = AuthState(isLoading: false, isAuthenticated: state.isAuthenticated, role: newRole);
  }

  Future<void> logout() async {
    AuthTokenHolder.token = null;
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_role');
    ref.invalidate(currentClinicProvider);
    ref.invalidate(currentUserProvider);
    state = AuthState(isLoading: false, isAuthenticated: false, role: 'admin');
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

final currentUserProvider = FutureProvider<User>((ref) async {
  final authState = ref.watch(authProvider);
  if (!authState.isAuthenticated) {
    throw Exception('Não autenticado');
  }
  final repository = ref.watch(authRepositoryProvider);
  final profileData = await repository.getProfile();
  return User.fromJson(profileData['user']);
});

final currentClinicProvider = FutureProvider<Clinic>((ref) async {
  final authState = ref.watch(authProvider);
  if (!authState.isAuthenticated) {
    throw Exception('Não autenticado');
  }
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/clinics/me');
  return Clinic.fromJson(response.data);
});
