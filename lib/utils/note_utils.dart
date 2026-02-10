class NoteUtils {
  static const List<String> noteNames = [
    "C",
    "C#",
    "D",
    "D#",
    "E",
    "F",
    "F#",
    "G",
    "G#",
    "A",
    "A#",
    "B",
  ];

  static double noteToN(String noteStr) {
    RegExp re = RegExp(r"^([A-G]#?)(\d+)$");
    var match = re.firstMatch(noteStr);
    if (match != null) {
      int noteIdx = noteNames.indexOf(match.group(1)!);
      int octave = int.parse(match.group(2)!);
      return (noteIdx + (octave * 12)) - 57.0;
    }
    // Try generic note matching if no octave
    RegExp generic = RegExp(r"^([A-G]#?)$");
    var gMatch = generic.firstMatch(noteStr);
    if (gMatch != null) {
      // Return base C0 offset for generic note?
      // Or maybe noteToN should return null?
      // Existing code expects a double.
      // Let's return a "base" N corresponding to octave 0 for reference,
      // but maybe we should throw or handle specifically.
      // Actually, let's keep it simple: If generic, return N for octave 4 (standard middle)
      // This effectively defaults generic notes to octave 4 for simple conversions.
      int noteIdx = noteNames.indexOf(gMatch.group(1)!);
      return (noteIdx + (4 * 12)) - 57.0;
    }
    return 0;
  }

  static bool isGeneric(String noteStr) {
    return !RegExp(r"\d+$").hasMatch(noteStr);
  }

  static double getClosestN(String noteStr, double referenceN) {
    if (!isGeneric(noteStr)) {
      return noteToN(noteStr);
    }
    // It's a generic note (e.g. "C")
    // Find the octave of referenceN
    // int refNoteIdx = ((referenceN + 57) % 12).round(); // Unused

    // Actually, we want to find N corresponding to noteStr that is closest to referenceN

    int targetIdx = noteNames.indexOf(noteStr);
    if (targetIdx == -1) return referenceN; // Fallback

    // referenceN = (refIdx + refOct * 12) - 57
    // We want targetN = (targetIdx + targetOct * 12) - 57
    // minimizing |targetN - referenceN|
    // approx: targetOct * 12 ~ referenceN + 57 - targetIdx
    // targetOct ~ (referenceN + 57 - targetIdx) / 12

    double estimatedOctave = (referenceN + 57 - targetIdx) / 12.0;
    int oct = estimatedOctave.round();

    return (targetIdx + (oct * 12)) - 57.0;
  }
}
