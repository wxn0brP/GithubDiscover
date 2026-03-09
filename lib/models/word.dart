class Word {
  final String word;
  final String language;
  final String? category;

  Word({required this.word, required this.language, this.category});

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      word: json['word'] as String,
      language: json['language'] as String,
      category: json['category'] as String?,
    );
  }
}
