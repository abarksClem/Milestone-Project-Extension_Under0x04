class AssessmentResult {
  final double accuracy;
  final double completeness;
  final double fluency;
  final double prosody;
  final double pronScore;
  final List<WordResult> words;

  AssessmentResult({
    required this.accuracy,
    required this.completeness,
    required this.fluency,
    required this.prosody,
    required this.pronScore,
    required this.words,
  });

  factory AssessmentResult.fromJson(Map<String, dynamic> result) {
    final nbestList = result["NBest"];
    if (nbestList == null || nbestList.isEmpty) {
      throw Exception("Missing NBest list");
    }

    final nbest = nbestList[0];

    // Azure returns the whole-utterance pronunciation scores as top-level
    // fields on the NBest entry (not nested under "PronunciationAssessment")
    // when using the header-based scoring config.
    final pa = nbest;

    return AssessmentResult(
      accuracy: (pa["AccuracyScore"] ?? 0).toDouble(),
      completeness: (pa["CompletenessScore"] ?? 0).toDouble(),
      fluency: (pa["FluencyScore"] ?? 0).toDouble(),
      prosody: (pa["ProsodyScore"] ?? 0).toDouble(),
      pronScore: (pa["PronScore"] ?? 0).toDouble(),
      words: ((nbest["Words"] ?? []) as List)
          .map((w) => WordResult.fromJson(w))
          .toList(),
    );
  }

  /// All phonemes across all words, in the order Azure returned them.
  List<PhonemeResult> get allPhonemes =>
      words.expand((w) => w.phonemes).toList();

  /// The sounds worth practicing again — anything scored below [threshold].
  /// Only populated when the request asked for "Phoneme" granularity.
  List<PhonemeResult> weakPhonemes({double threshold = 60}) =>
      allPhonemes.where((p) => p.accuracy < threshold).toList();
}

class WordResult {
  final String word;
  final double accuracy;
  final List<PhonemeResult> phonemes;

  WordResult({
    required this.word,
    required this.accuracy,
    this.phonemes = const [],
  });

  factory WordResult.fromJson(Map<String, dynamic> json) {
    final pa = json["PronunciationAssessment"] ?? {};

    return WordResult(
      word: json["Word"] ?? "",
      accuracy: (pa["AccuracyScore"] ?? 0).toDouble(),
      phonemes: ((json["Phonemes"] ?? []) as List)
          .map((p) => PhonemeResult.fromJson(p))
          .toList(),
    );
  }
}

class PhonemeResult {
  final String phoneme;
  final double accuracy;

  PhonemeResult({required this.phoneme, required this.accuracy});

  factory PhonemeResult.fromJson(Map<String, dynamic> json) {
    final pa = json["PronunciationAssessment"] ?? {};

    return PhonemeResult(
      phoneme: json["Phoneme"] ?? "",
      accuracy: (pa["AccuracyScore"] ?? 0).toDouble(),
    );
  }
}