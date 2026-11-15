# frozen_string_literal: true

require "test_helper"
require "support"

# A calendar day as the stack runs it (Calendar#day), and agreeing with
# the decisions. December 2026: every weekday runs `work`, the 24th a
# holiday.
class CalendarDayTest < Minitest::Test
    include ScheduleSupport

    DAY = Date.new(2026, 12, 24)

    def setup
        work = program("work", "06:45" => COMFORT, "08:30" => ECO,
                               "23:00" => NIGHT)
        @days = (0..6).to_h { [it, work] }
    end

    def test_the_day_as_stretches
        zone = zone_with(program(nil, "08:15" => COMFORT, "12:00" => :pass))
        stretches = Schedule::Layers::Calendar.new([holiday]).day(zone, DAY)
        assert_equal [["00:00", "24 08:15", "night", "timetable:work"],
                      ["08:15", "24 12:00", "comfort", "calendar:fr:holiday"],
                      ["12:00", "24 23:00", "eco", "timetable:work"],
                      ["23:00", "25 00:00", "night", "timetable:work"]],
                     stretches.map(&method(:shown))
    end

    # A holiday bound to an empty program says nothing for over a week:
    # the calendar passes the decision below, and the day shows it too.
    def test_the_day_view_agrees_where_the_calendar_passes_below
        zone = zone_with(program(nil, {}))
        long = holiday.with(first: DAY - 14, last: DAY + 1)
        decision = resolve("2026-12-24 12:00", zone:, layers: on(long))
        noon = Schedule::Layers::Calendar.new([long]).day(zone, DAY)
                                         .map(&method(:shown))[2]
        assert_equal ["08:30", "24 23:00", decision.label, decision.source],
                     noon
    end

    private

    def shown(stretch)
        [stretch.from.strftime("%H:%M"), stretch.to.strftime("%d %H:%M"),
         stretch.preset.name, stretch.source]
    end

    def zone_with(holiday)
        timetable = Schedule::Timetable.new(days: @days,
                                            specials: { "holiday" => holiday })
        Schedule::Zone.new(name: "living", timetable:)
    end

    def holiday = ScheduleSupport.holiday(DAY)

    def on(*entries) = [base, Schedule::Layers::Calendar.new(entries)]
end
