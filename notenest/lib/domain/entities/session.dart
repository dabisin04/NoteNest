class Session {
  final String userId;
  final String token;
  final DateTime expiresAt;

  Session({
    required this.userId,
    required this.token,
    required this.expiresAt,
  });

  bool get isValid => expiresAt.isAfter(DateTime.now());

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      userId: map['userId'] as String,
      token: map['token'] as String,
      expiresAt: DateTime.parse(map['expiresAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'token': token,
      'expiresAt': expiresAt.toIso8601String(),
    };
  }
}
