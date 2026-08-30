import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/pocket_money_entry.dart';

class PocketMoneyCalendarView extends StatelessWidget {
  final bool isAdmin;
  final bool hasSelectedUser;
  final Widget? userSelector;
  final Map<DateTime, List<PocketMoneyEntry>> events;
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;

  const PocketMoneyCalendarView({
    super.key,
    required this.isAdmin,
    required this.hasSelectedUser,
    this.userSelector,
    required this.events,
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
  });

  DateTime _normalizeDate(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        color: Colors.white,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pocket Money Calendar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (isAdmin && userSelector != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: userSelector!,
                    ),
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('Planned'),
                      const SizedBox(width: 12),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('Received'),
                    ],
                  ),
                ],
              ),
            ),
            if (!(isAdmin && !hasSelectedUser))
              Expanded(
                child: TableCalendar(
                  availableCalendarFormats: const {
                    CalendarFormat.month: 'Month',
                  },
                  firstDay: DateTime(2010, 1, 1),
                  lastDay: DateTime(2101, 12, 31),
                  focusedDay: focusedDay,
                  selectedDayPredicate: (day) =>
                      selectedDay != null && isSameDay(selectedDay, day),
                  eventLoader: (day) => events[_normalizeDate(day)] ?? [],
                  onDaySelected: onDaySelected,
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, dayEvents) {
                      if (dayEvents.isNotEmpty) {
                        final anyConfirmed = dayEvents.any(
                          (e) => (e as PocketMoneyEntry?)?.confirmed ?? false,
                        );
                        final color =
                            anyConfirmed ? Colors.green : Colors.orange;
                        return Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
