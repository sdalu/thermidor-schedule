# frozen_string_literal: true

require "test_helper"
require "support"

# A layer of the caller's own between the timetable and the calendar: on
# an ordinary day the calendar changes nothing, and passes what is below
# through; on a calendar day or its eve it decides. (Same December 2026
# as CalendarTest: the 24th and 25th holidays.)
class CalendarBelowTest < Minitest::Test
    include ScheduleSupport

    Entry = Schedule::Layers::Calendar::Entry

    CHRISTMAS = Entry.new(id: 1, calendar: "fr", priority: 8, zone: nil,
                          kind: "holiday", first: Date.new(2026, 12, 24),
                          last: Date.new(2026, 12, 25), description: nil)

    # The caller's own: the band lowered to eco, the rest kept.
    class Lower
        def apply(_zone, _now, below)
            below.with(setpoint: ScheduleSupport::ECO.setpoint, source: "lower")
        end
    end

    def setup
        work    = program("work", "06:45" => COMFORT, "23:00" => NIGHT)
        holiday = program("holiday", "08:15" => COMFORT, "23:30" => NIGHT)
        days = (0..6).to_h { [it, work] }
        timetable = Schedule::Timetable.new(days:,
                                            specials: { "holiday" => holiday })
        @zone = Schedule::Zone.new(name: "living", timetable:)
    end

    def test_an_ordinary_day_keeps_the_layer_below
        decision = resolve(at("2026-12-22 12:00"), [])
        assert_equal ["lower", ECO.setpoint], [decision.source,
                                               decision.setpoint]
    end

    # A calendar day later on changes nothing today.
    def test_a_calendar_day_later_keeps_the_layer_below
        decision = resolve(at("2026-12-22 12:00"), [CHRISTMAS])
        assert_equal "lower", decision.source
        assert_equal at("2026-12-22 23:00"), decision.until
    end

    # On the eve, the next change is the holiday's: the calendar decides.
    def test_the_eve_of_a_calendar_day_is_the_calendar_s
        decision = resolve(at("2026-12-23 23:30"), [CHRISTMAS])
        assert_equal ["timetable:work", at("2026-12-24 08:15")],
                     [decision.source, decision.until]
    end

    def test_a_calendar_day_still_decides
        decision = resolve(at("2026-12-24 12:00"), [CHRISTMAS])
        assert_equal "calendar:fr:holiday", decision.source
    end

    # The early hours of a holiday carry on from the evening before:
    # the calendar decides, though that evening was an ordinary day.
    def test_a_holiday_s_early_hours_still_carry_on
        decision = resolve(at("2026-12-24 07:00"), [CHRISTMAS])
        assert_equal ["timetable:work", NIGHT.setpoint],
                     [decision.source, decision.setpoint]
    end

    private

    def resolve(now, entries)
        Schedule::Stack.new([base, Lower.new,
                             Schedule::Layers::Calendar.new(entries)])
                       .resolve(@zone, now)
    end
end
