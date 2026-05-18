class NotificationSummary {
  const NotificationSummary({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAtLabel,
    required this.isRead,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String createdAtLabel;
  final bool isRead;

  factory NotificationSummary.fromJson(Map<String, dynamic> json) {
    return NotificationSummary(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Notificacao',
      body: json['body']?.toString() ?? '',
      createdAtLabel: _dateLabel(json['createdAt']?.toString() ?? ''),
      isRead: json['readAt'] != null,
    );
  }

  static String _dateLabel(String value) {
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) {
      return 'Agora';
    }

    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');

    return '$day/$month as $hour:$minute';
  }
}
