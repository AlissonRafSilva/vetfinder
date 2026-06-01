class OpportunityFormatter {
  const OpportunityFormatter._();

  static String amountLabel(Object? amount) {
    if (amount == null) {
      return 'Valor a combinar';
    }

    return 'R\$ ${amount.toString()}';
  }

  static String urgencyLabel(String urgencyLevel) {
    switch (urgencyLevel.toUpperCase()) {
      case 'HIGH':
        return 'Urgente';
      case 'CRITICAL':
        return 'Critico';
      case 'LOW':
        return 'Baixa urgencia';
      default:
        return 'Aberta';
    }
  }

  static String statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return 'Aberta';
      case 'FILLED':
        return 'Preenchida';
      case 'CANCELLED':
        return 'Cancelada';
      case 'COMPLETED':
        return 'Concluida';
      default:
        return status.isEmpty ? 'Em andamento' : status;
    }
  }

  static String shiftSummary({
    required String startAt,
    required String endAt,
  }) {
    final start = _tryParse(startAt);
    final end = _tryParse(endAt);

    if (start == null || end == null) {
      return 'Horário a combinar';
    }

    return '${shortDate(start)} • ${timeRange(start, end)}';
  }

  static String dateHeadline({
    required String startAt,
    required String endAt,
  }) {
    final start = _tryParse(startAt);
    final end = _tryParse(endAt);

    if (start == null || end == null) {
      return 'Data a combinar';
    }

    if (_isSameDay(start, end)) {
      return '${fullDate(start)} • ${timeRange(start, end)}';
    }

    return '${fullDate(start)} • ${hourLabel(start)} até ${fullDate(end)} • ${hourLabel(end)}';
  }

  static String durationLabel({
    required String startAt,
    required String endAt,
  }) {
    final start = _tryParse(startAt);
    final end = _tryParse(endAt);

    if (start == null || end == null) {
      return 'Duracao a confirmar';
    }

    final minutes = end.difference(start).inMinutes;
    if (minutes <= 0) {
      return 'Duracao a confirmar';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (remainingMinutes == 0) {
      return '${hours}h de plantão';
    }

    return '${hours}h${remainingMinutes.toString().padLeft(2, '0')} de plantão';
  }

  static String hourLabel(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  static String timeRange(DateTime start, DateTime end) {
    return '${hourLabel(start)} às ${hourLabel(end)}';
  }

  static String shortDate(DateTime dateTime) {
    return '${_weekdayShort(dateTime.weekday)}, ${dateTime.day} ${_monthShort(dateTime.month)}';
  }

  static String fullDate(DateTime dateTime) {
    return '${_weekdayFull(dateTime.weekday)}, ${dateTime.day} de ${_monthFull(dateTime.month)}';
  }

  static DateTime? _tryParse(String value) {
    if (value.isEmpty) {
      return null;
    }

    return DateTime.tryParse(value)?.toLocal();
  }

  static bool _isSameDay(DateTime start, DateTime end) {
    return start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
  }

  static String _weekdayShort(int weekday) {
    const values = ['seg', 'ter', 'qua', 'qui', 'sex', 'sab', 'dom'];
    return values[(weekday - 1).clamp(0, values.length - 1)];
  }

  static String _weekdayFull(int weekday) {
    const values = [
      'Segunda',
      'Terca',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sabado',
      'Domingo',
    ];

    return values[(weekday - 1).clamp(0, values.length - 1)];
  }

  static String _monthShort(int month) {
    const values = [
      'jan',
      'fev',
      'mar',
      'abr',
      'mai',
      'jun',
      'jul',
      'ago',
      'set',
      'out',
      'nov',
      'dez',
    ];

    return values[(month - 1).clamp(0, values.length - 1)];
  }

  static String _monthFull(int month) {
    const values = [
      'janeiro',
      'fevereiro',
      'marco',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];

    return values[(month - 1).clamp(0, values.length - 1)];
  }
}
