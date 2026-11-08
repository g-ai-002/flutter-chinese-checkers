/// 一道残局的最佳成绩：星级越高越好，同星级步数越少越好。
class ChallengeResult {
  const ChallengeResult({required this.levelId, required this.stars, required this.moves});

  final String levelId;
  final int stars;
  final int moves;

  bool beats(ChallengeResult other) =>
      stars > other.stars || (stars == other.stars && moves < other.moves);

  Map<String, Object> toJson() => {'id': levelId, 'stars': stars, 'moves': moves};

  /// 严格解析持久化数据，损坏或缺字段时返回 null。
  static ChallengeResult? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final stars = json['stars'];
    final moves = json['moves'];
    if (id is! String || id.isEmpty) return null;
    if (stars is! int || stars < 1 || stars > 3) return null;
    if (moves is! int || moves < 1) return null;
    return ChallengeResult(levelId: id, stars: stars, moves: moves);
  }
}
