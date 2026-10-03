import 'package:flutter/material.dart';
import '../models/schedule_date.dart';

enum DateGranularity { month, day, hour }

class ScheduleDatePickerDialog extends StatefulWidget {
  final ScheduleDate? initialDate;

  const ScheduleDatePickerDialog({super.key, this.initialDate});

  static Future<ScheduleDate?> show(
    BuildContext context, {
    ScheduleDate? initialDate,
  }) {
    return showDialog<ScheduleDate>(
      context: context,
      builder: (ctx) => ScheduleDatePickerDialog(initialDate: initialDate),
    );
  }

  @override
  State<ScheduleDatePickerDialog> createState() => _ScheduleDatePickerDialogState();
}

class _ScheduleDatePickerDialogState extends State<ScheduleDatePickerDialog> {
  late DateGranularity _granularity;
  late int _year;
  late int _month;
  late int _day;
  late int _hour;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final init = widget.initialDate;

    if (init == null) {
      _granularity = DateGranularity.day;
      _year = now.year;
      _month = now.month;
      _day = now.day;
      _hour = now.hour;
    } else {
      _year = init.year;
      _month = init.month;
      _day = init.day ?? 1;
      _hour = init.hour ?? 12;

      if (init.hour != null) {
        _granularity = DateGranularity.hour;
      } else if (init.day != null) {
        _granularity = DateGranularity.day;
      } else {
        _granularity = DateGranularity.month;
      }
    }
  }

  ScheduleDate get _currentDate {
    switch (_granularity) {
      case DateGranularity.month:
        return ScheduleDate(year: _year, month: _month);
      case DateGranularity.day:
        return ScheduleDate(year: _year, month: _month, day: _day);
      case DateGranularity.hour:
        return ScheduleDate(year: _year, month: _month, day: _day, hour: _hour);
    }
  }

  int _daysInMonth(int year, int month) {
    final nextMonth = month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    return nextMonth.subtract(const Duration(days: 1)).day;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxDays = _daysInMonth(_year, _month);
    if (_day > maxDays) _day = maxDays;

    final curr = _currentDate;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.calendar_month),
          SizedBox(width: 8),
          Text('Select Deadline'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Granularity',
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              SegmentedButton<DateGranularity>(
                segments: const [
                  ButtonSegment(
                    value: DateGranularity.month,
                    label: Text('Month'),
                    icon: Icon(Icons.calendar_view_month),
                  ),
                  ButtonSegment(
                    value: DateGranularity.day,
                    label: Text('Day'),
                    icon: Icon(Icons.calendar_today),
                  ),
                  ButtonSegment(
                    value: DateGranularity.hour,
                    label: Text('Hour'),
                    icon: Icon(Icons.access_time),
                  ),
                ],
                selected: {_granularity},
                onSelectionChanged: (set) {
                  setState(() {
                    _granularity = set.first;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Year and Month
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<int>(
                      initialValue: _year,
                      decoration: const InputDecoration(
                        labelText: 'Year',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: List.generate(10, (i) => 2024 + i)
                          .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _year = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: DropdownButtonFormField<int>(
                      initialValue: _month,
                      decoration: const InputDecoration(
                        labelText: 'Month',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: List.generate(12, (i) => i + 1)
                          .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text('Month $m'),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _month = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Day (if day or hour granularity)
              if (_granularity != DateGranularity.month) ...[
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _day > maxDays ? maxDays : _day,
                        decoration: const InputDecoration(
                          labelText: 'Day',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: List.generate(maxDays, (i) => i + 1)
                            .map((d) => DropdownMenuItem(value: d, child: Text('Day $d')))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _day = val);
                        },
                      ),
                    ),
                    if (_granularity == DateGranularity.hour) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _hour,
                          decoration: const InputDecoration(
                            labelText: 'Hour (24h)',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          items: List.generate(24, (i) => i)
                              .map((h) => DropdownMenuItem(
                                    value: h,
                                    child: Text('${h.toString().padLeft(2, '0')}:00'),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _hour = val);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Info card on end instant
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Deadline Instant',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      curr.formatted,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'End instant: ${curr.endInstant.toLocal().toString().replaceAll('.000', '')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_currentDate),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
