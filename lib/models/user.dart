class User {
  final int? id;
  final String access;
  final String name;
  final String? password;

  User(this.password, {required this.id, required this.access, required this.name});

  bool get isAdmin => access == 'admin';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      json['Password'] as String?,
      id: json['ID'] as int,
      name: json['Name'] as String,
      access: json['Access'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'password': password,
      'id': id,
      'name': name,
      'access': access,
    };
  }
}
