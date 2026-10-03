import 'package:intl/intl.dart';

/// Represents an instant in time to the granularity of 1 hour, 1 day, or 1 month.
/// Conforms to common.schema.json#/$defs/date.
///
/// "Date that this task must be completed by. The specific instant is given
/// by the end of the date's granularity interval."
class ScheduleDate implements Comparable<ScheduleDate> {
  final int year;
  final int month;
  final int? day;
  final int? hour;

  const ScheduleDate({
    required this.year,
    required this.month,
    this.day,
    this.hour,
  }) : assert(month >= 1 && month <= 12, 'Month must be between 1 and 12'),
       assert(day == null || (day >= 1 && day <= 31), 'Day must be between 1 and 31'),
       assert(hour == null || (hour >= 0 && hour <= 23), 'Hour must be between 0 and 23');

  /// The end instant of this date's granularity interval.
  /// - 1 month: end of that month (last day, 23:59:59.999)
  /// - 1 day: end of that day (23:59:59.999)
  /// - 1 hour: end of that hour (59:59.999)
  DateTime get endInstant {
    if (day == null) {
      // Month granularity: last millisecond of the month
      final nextMonth = month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
      return nextMonth.subtract(const Duration(milliseconds: 1));
    } else if (hour == null) {
      // Day granularity: last millisecond of the day
      return DateTime(year, month, day!, 23, 59, 59, 999);
    } else {
      // Hour granularity: last millisecond of the specified hour
      return DateTime(year, month, day!, hour!, 59, 59, 999);
    }
  }

  /// Factory from DateTime with specific granularity
  factory ScheduleDate.fromDateTime(
    DateTime dt, {
    bool includeDay = true,
    bool includeHour = true,
  }) {
    return ScheduleDate(
      year: dt.year,
      month: dt.month,
      day: includeDay ? dt.day : null,
      hour: (includeDay && includeHour) ? dt.hour : null,
    );
  }

  factory ScheduleDate.fromJson(Map<String, dynamic> json) {
    return ScheduleDate(
      year: json['year'] as int,
      month: json['month'] as int,
      day: json['day'] as int?,
      hour: json['hour'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'year': year,
      'month': month,
    };
    if (day != null) map['day'] = day;
    if (hour != null) map['hour'] = hour;
    return map;
  }

  String get formatted {
    final monthName = DateFormat('MMM').format(DateTime(year, month));
    if (day == null) {
      return '$monthName $year';
    } else if (hour == null) {
      return '$monthName $day, $year';
    } else {
      final hourStr = hour!.toString().padLeft(2, '0');
      return '$monthName $day, $year $hourStr:00';
    }
  }

  @override
  int compareTo(ScheduleDate other) {
    return endInstant.compareTo(other.endInstant);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleDate &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          month == other.month &&
          day == other.day &&
          hour == other.hour;

  @override
  int get hashCode => Object.hash(year, month, day, hour);

  @override
  String toString() => formatted;
}
