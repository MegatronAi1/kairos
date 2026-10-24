import 'package:kairos_pager/core/models/models.dart';

/// One plant of the signed-in company, with live roll-ups (GET /plants).
class PlantSummary {
  const PlantSummary({
    required this.id,
    required this.name,
    required this.city,
    required this.country,
    required this.processId,
    required this.processName,
    required this.state,
    this.processFamily,
    this.reactorIds = const [],
    this.alarmsOpen = 0,
    this.powerKw,
  });

  factory PlantSummary.fromJson(Json j) => PlantSummary(
    id: j['id'] as String,
    name: j['name'] as String? ?? j['id'] as String,
    city: j['city'] as String? ?? '',
    country: j['country'] as String? ?? '',
    processId: j['process_id'] as String? ?? '',
    processName: j['process_name'] as String? ?? '',
    processFamily: j['process_family'] as String?,
    state: HealthState.parse(j['state']),
    reactorIds: ((j['reactor_ids'] as List?) ?? const []).cast<String>(),
    alarmsOpen: (j['alarms_open'] as num?)?.toInt() ?? 0,
    powerKw: (j['power_kw'] as num?)?.toDouble(),
  );

  final String id;
  final String name;
  final String city;
  final String country;
  final String processId;
  final String processName;
  final String? processFamily;
  final HealthState state;
  final List<String> reactorIds;
  final int alarmsOpen;
  final double? powerKw;

  String get familyLabel => switch (processFamily) {
    'biomass' => 'Biomass fermentation',
    'precision' => 'Precision fermentation',
    _ => '',
  };
}

/// Demo account offered on the sign-in screen (GET /auth/demo-accounts).
class DemoAccount {
  const DemoAccount({required this.email, required this.password, required this.name, required this.role});

  factory DemoAccount.fromJson(Json j) => DemoAccount(
    email: j['email'] as String,
    password: j['password'] as String,
    name: j['name'] as String? ?? '',
    role: j['role'] as String? ?? '',
  );

  final String email;
  final String password;
  final String name;
  final String role;
}

/// Result of POST /auth/login.
class LoginResult {
  const LoginResult({
    required this.token,
    required this.userName,
    required this.userRole,
    required this.userEmail,
    required this.tenantName,
  });

  factory LoginResult.fromJson(Json j) {
    final user = (j['user'] as Json?) ?? const {};
    final tenant = (j['tenant'] as Json?) ?? const {};
    return LoginResult(
      token: j['token'] as String? ?? '',
      userName: user['name'] as String? ?? '',
      userRole: user['role'] as String? ?? '',
      userEmail: user['email'] as String? ?? '',
      tenantName: tenant['name'] as String? ?? '',
    );
  }

  final String token;
  final String userName;
  final String userRole;
  final String userEmail;
  final String tenantName;
}
