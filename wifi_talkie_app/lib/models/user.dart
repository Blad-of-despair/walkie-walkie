class User {
  final String id;
  final String nickname;
  bool isTalking;

  User({required this.id, required this.nickname, this.isTalking = false});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
    );
  }
}
