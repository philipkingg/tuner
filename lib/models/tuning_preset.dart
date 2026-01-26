class TuningPreset {
  final String name;
  final List<String> notes;
  final bool isCustom;

  TuningPreset({required this.name, required this.notes, this.isCustom = false});

  Map<String, dynamic> toJson() => {
    'name': name,
    'notes': notes,
    'isCustom': isCustom,
  };

  factory TuningPreset.fromJson(Map<String, dynamic> json) {
    return TuningPreset(
      name: json['name'],
      notes: List<String>.from(json['notes']),
      isCustom: json['isCustom'] ?? false,
    );
  }
}
