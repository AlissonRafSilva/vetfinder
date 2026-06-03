class AvailabilitySlotModel {
  const AvailabilitySlotModel({
    required this.weekday,
    required this.startTime,
    required this.endTime,
  });

  final int weekday;
  final String startTime;
  final String endTime;

  factory AvailabilitySlotModel.fromJson(Map<String, dynamic> json) {
    return AvailabilitySlotModel(
      weekday: (json['weekday'] as num?)?.toInt() ?? 1,
      startTime: json['startTime']?.toString() ?? '09:00',
      endTime: json['endTime']?.toString() ?? '18:00',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'weekday': weekday,
      'startTime': startTime,
      'endTime': endTime,
      'availabilityType': 'RECURRING',
    };
  }

  String get weekdayLabel {
    const values = [
      'Segunda',
      'Terça',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sábado',
      'Domingo',
    ];

    return values[(weekday - 1).clamp(0, values.length - 1)];
  }

  String get displayLabel => '$weekdayLabel • $startTime às $endTime';
}
