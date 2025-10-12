import 'package:college_event_calendar/models/notifications/reminder_policy.dart';
import 'package:college_event_calendar/services/notifications/strategies/reminder_strategy.dart';
import 'package:college_event_calendar/services/notifications/strategies/fifteen_minutes_strategy.dart';
import 'package:college_event_calendar/services/notifications/strategies/one_hour_strategy.dart';
import 'package:college_event_calendar/services/notifications/strategies/one_day_strategy.dart';
import 'package:college_event_calendar/services/notifications/strategies/three_days_strategy.dart';
import 'package:college_event_calendar/services/notifications/strategies/one_week_strategy.dart';
import 'package:college_event_calendar/services/notifications/strategies/custom_strategy.dart';

class ReminderStrategyFactory {
  static final Map<ReminderTiming, ReminderStrategy Function()> _strategies = {
    ReminderTiming.fifteenMinutes: () => FifteenMinutesStrategy(),
    ReminderTiming.oneHour: () => OneHourStrategy(),
    ReminderTiming.oneDay: () => OneDayStrategy(),
    ReminderTiming.threeDays: () => ThreeDaysStrategy(),
    ReminderTiming.oneWeek: () => OneWeekStrategy(),
  };

  static ReminderStrategy getStrategy(ReminderTiming timing, {int? customMinutes}) {
    if (timing == ReminderTiming.custom) {
      if (customMinutes == null || customMinutes <= 0) {
        throw Exception('Custom timing requires valid minutes');
      }
      return CustomStrategy(customMinutes);
    }

    final strategyFactory = _strategies[timing];
    if (strategyFactory == null) {
      throw Exception('Unknown reminder timing: $timing');
    }

    return strategyFactory();
  }

  static List<Map<String, dynamic>> getAllTimingOptions() {
    return ReminderTiming.values.map((timing) {
      return {
        'value': timing,
        'label': timing.label,
      };
    }).toList();
  }
}