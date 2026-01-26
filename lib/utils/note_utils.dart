class NoteUtils {
  static const List<String> noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];

  static double noteToN(String noteStr) {
    RegExp re = RegExp(r"([A-G]#?)(\d)");
    var match = re.firstMatch(noteStr);
    if (match == null) return 0;
    int noteIdx = noteNames.indexOf(match.group(1)!);
    int octave = int.parse(match.group(2)!);
    return (noteIdx + (octave * 12)) - 57.0;
  }
}
