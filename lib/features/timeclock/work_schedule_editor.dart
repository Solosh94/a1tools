import 'package:flutter/material.dart';
import 'time_clock_service.dart';

/// Work Schedule Editor Dialog
/// Allows managers to set work schedule for a user
class WorkScheduleEditor extends StatefulWidget {
  final String username;
  final String displayName;
  final WorkSchedule? initialSchedule;
  
  const WorkScheduleEditor({
    super.key,
    required this.username,
    required this.displayName,
    this.initialSchedule,
  });
  
  /// Show the schedule editor dialog
  static Future<bool?> show(BuildContext context, {
    required String username,
    required String displayName,
    WorkSchedule? initialSchedule,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => WorkScheduleEditor(
        username: username,
        displayName: displayName,
        initialSchedule: initialSchedule,
      ),
    );
  }

  @override
  State<WorkScheduleEditor> createState() => _WorkScheduleEditorState();
}

class _WorkScheduleEditorState extends State<WorkScheduleEditor> {
  late WorkSchedule _schedule;
  bool _isSaving = false;
  bool _isLoading = true;
  
  final List<String> _days = [
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
  ];
  
  final Map<String, String> _dayLabels = {
    'monday': 'Monday',
    'tuesday': 'Tuesday',
    'wednesday': 'Wednesday',
    'thursday': 'Thursday',
    'friday': 'Friday',
    'saturday': 'Saturday',
    'sunday': 'Sunday',
  };
  
  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }
  
  Future<void> _loadSchedule() async {
    if (widget.initialSchedule != null) {
      setState(() {
        _schedule = widget.initialSchedule!;
        _isLoading = false;
      });
      return;
    }
    
    final schedule = await TimeClockService.getSchedule(widget.username);
    
    if (mounted) {
      setState(() {
        _schedule = schedule ?? WorkSchedule.defaultSchedule();
        _isLoading = false;
      });
    }
  }
  
  Future<void> _saveSchedule() async {
    setState(() => _isSaving = true);
    
    final success = await TimeClockService.setSchedule(widget.username, _schedule);
    
    if (mounted) {
      setState(() => _isSaving = false);
      
      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Work schedule saved')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save schedule')),
        );
      }
    }
  }
  
  void _updateDay(String day, DaySchedule daySchedule) {
    setState(() {
      switch (day) {
        case 'monday':
          _schedule = _schedule.copyWith(monday: daySchedule);
          break;
        case 'tuesday':
          _schedule = _schedule.copyWith(tuesday: daySchedule);
          break;
        case 'wednesday':
          _schedule = _schedule.copyWith(wednesday: daySchedule);
          break;
        case 'thursday':
          _schedule = _schedule.copyWith(thursday: daySchedule);
          break;
        case 'friday':
          _schedule = _schedule.copyWith(friday: daySchedule);
          break;
        case 'saturday':
          _schedule = _schedule.copyWith(saturday: daySchedule);
          break;
        case 'sunday':
          _schedule = _schedule.copyWith(sunday: daySchedule);
          break;
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.schedule, color: Color(0xFFF49320)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Work Schedule'),
                Text(
                  widget.displayName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Quick presets
                    Wrap(
                      spacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('Mon-Fri 9-5'),
                          onPressed: () {
                            setState(() {
                              _schedule = WorkSchedule.defaultSchedule();
                            });
                          },
                        ),
                        ActionChip(
                          label: const Text('Mon-Fri 8-4'),
                          onPressed: () {
                            final workDay = DaySchedule(start: '08:00', end: '16:00', isOff: false);
                            final offDay = DaySchedule(start: null, end: null, isOff: true);
                            setState(() {
                              _schedule = WorkSchedule(
                                monday: workDay,
                                tuesday: workDay,
                                wednesday: workDay,
                                thursday: workDay,
                                friday: workDay,
                                saturday: offDay,
                                sunday: offDay,
                              );
                            });
                          },
                        ),
                        ActionChip(
                          label: const Text('All Days Off'),
                          onPressed: () {
                            final offDay = DaySchedule(start: null, end: null, isOff: true);
                            setState(() {
                              _schedule = WorkSchedule(
                                monday: offDay,
                                tuesday: offDay,
                                wednesday: offDay,
                                thursday: offDay,
                                friday: offDay,
                                saturday: offDay,
                                sunday: offDay,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    
                    // Day-by-day schedule
                    ..._days.map((day) => _buildDayRow(day)),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveSchedule,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF49320),
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
  
  Widget _buildDayRow(String day) {
    final daySchedule = _schedule.getDay(day) ?? 
        DaySchedule(start: '09:00', end: '17:00', isOff: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Day label
          SizedBox(
            width: 100,
            child: Text(
              _dayLabels[day]!,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: daySchedule.isOff 
                    ? (isDark ? Colors.white38 : Colors.black38)
                    : null,
              ),
            ),
          ),
          
          // Day off toggle
          SizedBox(
            width: 100,
            child: Row(
              children: [
                Checkbox(
                  value: daySchedule.isOff,
                  onChanged: (value) {
                    _updateDay(day, DaySchedule(
                      start: daySchedule.start,
                      end: daySchedule.end,
                      isOff: value ?? false,
                    ));
                  },
                  activeColor: Colors.orange,
                ),
                Text(
                  'Day Off',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          
          // Time pickers (disabled if day off)
          Expanded(
            child: Opacity(
              opacity: daySchedule.isOff ? 0.3 : 1,
              child: IgnorePointer(
                ignoring: daySchedule.isOff,
                child: Row(
                  children: [
                    // Start time
                    Expanded(
                      child: _TimePickerField(
                        label: 'Start',
                        value: daySchedule.start ?? '09:00',
                        onChanged: (value) {
                          _updateDay(day, DaySchedule(
                            start: value,
                            end: daySchedule.end,
                            isOff: daySchedule.isOff,
                          ));
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('to'),
                    ),
                    // End time
                    Expanded(
                      child: _TimePickerField(
                        label: 'End',
                        value: daySchedule.end ?? '17:00',
                        onChanged: (value) {
                          _updateDay(day, DaySchedule(
                            start: daySchedule.start,
                            end: value,
                            isOff: daySchedule.isOff,
                          ));
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Time picker field widget
class _TimePickerField extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  
  const _TimePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showTimePicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade600),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(value),
            const Icon(Icons.access_time, size: 16),
          ],
        ),
      ),
    );
  }
  
  Future<void> _showTimePicker(BuildContext context) async {
    final parts = value.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts[1]) ?? 0,
    );
    
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFF49320),
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      final newValue = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      onChanged(newValue);
    }
  }
}

/// Simple schedule display widget (for viewing only)
class WorkScheduleDisplay extends StatelessWidget {
  final WorkSchedule? schedule;
  
  const WorkScheduleDisplay({super.key, this.schedule});
  
  @override
  Widget build(BuildContext context) {
    if (schedule == null) {
      return const Text(
        'No schedule set',
        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      );
    }
    
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final schedules = [
      schedule!.monday,
      schedule!.tuesday,
      schedule!.wednesday,
      schedule!.thursday,
      schedule!.friday,
      schedule!.saturday,
      schedule!.sunday,
    ];
    
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: List.generate(7, (index) {
        final daySchedule = schedules[index];
        final isOff = daySchedule?.isOff ?? true;
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isOff 
                ? Colors.grey.withValues(alpha: 0.3)
                : const Color(0xFFF49320).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            days[index],
            style: TextStyle(
              fontSize: 11,
              color: isOff ? Colors.grey : const Color(0xFFF49320),
              fontWeight: isOff ? FontWeight.normal : FontWeight.bold,
            ),
          ),
        );
      }),
    );
  }
}
