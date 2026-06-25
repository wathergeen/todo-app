class UserModel {
  const UserModel({required this.accessToken});

  final String accessToken;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(accessToken: json['access_token'] as String);
  }

  Map<String, dynamic> toJson() {
    return {'access_token': accessToken};
  }
}
