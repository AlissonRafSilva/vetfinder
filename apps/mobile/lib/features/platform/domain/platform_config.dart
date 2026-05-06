class PlatformConfig {
  const PlatformConfig({
    required this.platformFeeRate,
    required this.platformFeePercentLabel,
  });

  final double platformFeeRate;
  final String platformFeePercentLabel;

  factory PlatformConfig.fromJson(Map<String, dynamic> json) {
    final parsedRate = _parseDouble(json['platformFeeRate']);

    return PlatformConfig(
      platformFeeRate: parsedRate ?? 0.03,
      platformFeePercentLabel:
          json['platformFeePercentLabel']?.toString() ?? '3%',
    );
  }

  static double? _parseDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }
}
