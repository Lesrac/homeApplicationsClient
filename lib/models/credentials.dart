class Credentials {
  String username;
  String password;
  bool admin;
  String backendAddress;
  int id;

  Credentials({
    required this.username,
    required this.password,
    required this.backendAddress,
    required this.admin,
    required this.id,
  });

  Map<String, dynamic> toJson() => {
    'username': username,
    'password': password,
    'backendAddress': backendAddress,
    'admin': admin,
    'id': id,
  };

  factory Credentials.fromJson(Map<String, dynamic> json) => Credentials(
    admin: json['admin'] ?? false,
    username: json['username'],
    password: json['password'],
    backendAddress: json['backendAddress'],
    id: json['id'],
  );
}