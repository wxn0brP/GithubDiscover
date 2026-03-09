class Repo {
  final String fullName;
  final String htmlUrl;
  final String? description;
  final int stargazersCount;
  final int forksCount;
  final String? language;
  final DateTime updatedAt;

  Repo({
    required this.fullName,
    required this.htmlUrl,
    this.description,
    required this.stargazersCount,
    required this.forksCount,
    this.language,
    required this.updatedAt,
  });

  factory Repo.fromJson(Map<String, dynamic> json) {
    return Repo(
      fullName: json['full_name'] as String,
      htmlUrl: json['html_url'] as String,
      description: json['description'] as String?,
      stargazersCount: json['stargazers_count'] as int,
      forksCount: json['forks_count'] as int,
      language: json['language'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
