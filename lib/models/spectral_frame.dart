class SpectralFrame {
  final List<double> magnitudes;
  final int loudestBin;
  final int timestamp;

  const SpectralFrame({
    required this.magnitudes,
    required this.loudestBin,
    required this.timestamp,
  });
}
