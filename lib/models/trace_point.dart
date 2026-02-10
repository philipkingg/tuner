class TracePoint {
  final double cents;
  final double note; // The lerped note index
  final int timestamp; // millisecondsSinceEpoch

  TracePoint({
    required this.cents,
    required this.note,
    required this.timestamp,
  });
}
