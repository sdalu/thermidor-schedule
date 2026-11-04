# frozen_string_literal: true

require "test_helper"
require "support"

# December 2026: the 23rd is a Wednesday, the 24th and 25th a Thursday
# and a Friday given as holidays, the 26th a Saturday.
class CalendarTest < Minitest::Test
    include ScheduleSupport

    Entry = Schedule::Layers::Calendar::Entry

    CHRISTMAS = Entry.new(id: 1, calendar: "fr", priority: 8, zone: nil,
                          kind: "holiday", first: Date.new(2026, 12, 24),
                          last: Date.new(2026, 12, 25), description: nil)
    LEAVE = CHRISTMAS.with(id: 2, calendar: "leave", priority: 5,
                           kind: "leave", first: Date.new(2026, 12, 21))

    def setup
        work    = program("work", "06:45" => COMFORT, "08:30" => ECO,
                                  "23:00" => NIGHT)
        weekend = program("weekend", "08:00" => COMFORT, "23:30" => NIGHT)
        holiday = program("holiday", "08:15" => [COMFORT, :quick],
                                     "23:30" => NIGHT)
        days = (1..5).to_h { [it, work] }.merge(6 => weekend, 0 => weekend)
        timetable = Schedule::Timetable.new(days:,
                                            specials: { "holiday" => holiday })
        @zone = Schedule::Zone.new(name: "living", timetable:)
    end

    def test_a_holiday_runs_the_zone_holiday_program
        decision = resolve("2026-12-24 09:00", layers: calendar(CHRISTMAS))
        assert_equal ["comfort", :quick, "calendar:fr:holiday",
                      at("2026-12-24 23:30")],
                     decision.to_h.values_at(:label, :strategy, :source, :until)
    end

    def test_early_hours_carry_on_from_the_evening_before
        decision = resolve("2026-12-24 07:00", layers: calendar(CHRISTMAS))
        assert_equal ["night", "timetable:work", at("2026-12-24 08:15")],
                     decision.to_h.values_at(:label, :source, :until)
    end

    def test_the_eve_already_waits_for_the_holiday_program
        decision = resolve("2026-12-23 23:30", layers: calendar(CHRISTMAS))
        assert_equal at("2026-12-24 08:15"), decision.until
    end

    def test_the_day_after_carries_on_from_the_holiday
        decision = resolve("2026-12-26 01:00", layers: calendar(CHRISTMAS))
        assert_equal ["night", "calendar:fr:holiday", at("2026-12-26 08:00")],
                     decision.to_h.values_at(:label, :source, :until)
    end

    def test_a_weekday_kind_runs_that_weekday_program
        sunday = CHRISTMAS.with(kind: "sun", first: Date.new(2026, 12, 31),
                                last: Date.new(2026, 12, 31))
        decision = resolve("2026-12-31 09:00", layers: calendar(sunday))
        assert_equal %w[comfort calendar:fr:sun],
                     decision.to_h.values_at(:label, :source)
    end

    def test_a_zone_without_that_special_day_keeps_its_week
        timetable = @zone.timetable.with(specials: {})
        office    = Schedule::Zone.new(name: "office", timetable:)
        decision = resolve("2026-12-24 07:00", zone: office,
                                               layers: calendar(CHRISTMAS))
        assert_equal %w[comfort timetable:work],
                     decision.to_h.values_at(:label, :source)
    end

    def test_a_zone_entry_beats_the_house_entry
        own = CHRISTMAS.with(id: 2, zone: "living", kind: "sun")
        decision = resolve("2026-12-24 08:10", layers: calendar(CHRISTMAS, own))
        assert_equal %w[comfort calendar:fr:sun],
                     decision.to_h.values_at(:label, :source)
    end

    def test_a_higher_priority_calendar_wins
        leave = CHRISTMAS.with(id: 2, calendar: "leave", priority: 3,
                               kind: "sun")
        layers   = calendar(CHRISTMAS, leave)
        decision = resolve("2026-12-24 08:10", layers:)
        assert_equal "calendar:leave:sun", decision.source
    end

    def test_priority_comes_before_zone
        own = CHRISTMAS.with(id: 2, zone: "living", kind: "sun", priority: 9)
        decision = resolve("2026-12-24 08:20", layers: calendar(CHRISTMAS, own))
        assert_equal "calendar:fr:holiday", decision.source
    end

    def test_the_latest_entry_breaks_a_tie
        later = CHRISTMAS.with(id: 2, kind: "sun")
        layers   = calendar(CHRISTMAS, later)
        decision = resolve("2026-12-24 08:10", layers:)
        assert_equal "calendar:fr:sun", decision.source
    end

    def test_an_entry_for_another_zone_changes_nothing
        other = CHRISTMAS.with(zone: "office")
        decision = resolve("2026-12-24 07:00", layers: calendar(other))
        assert_equal %w[comfort timetable:work],
                     decision.to_h.values_at(:label, :source)
    end

    # Leave (priority 5) over Christmas (8): the office has a holiday
    # program but no leave one, so leave says nothing to it.
    def test_an_entry_the_zone_cannot_use_lets_the_next_one_through
        office = office_with("holiday" => holiday)
        layers = calendar(CHRISTMAS, LEAVE)
        decision = resolve("2026-12-24 09:00", zone: office, layers:)
        assert_equal ["comfort", "calendar:fr:holiday", at("2026-12-24 23:30")],
                     decision.to_h.values_at(:label, :source, :until)
        assert_equal at("2026-12-24 08:15"),
                     resolve("2026-12-23 23:30", zone: office, layers:).until
    end

    def test_usual_takes_the_entry_and_runs_the_weekday
        office = office_with("holiday" => holiday,
                             "leave" => Schedule::Timetable::USUAL)
        layers = calendar(CHRISTMAS, LEAVE)
        decision = resolve("2026-12-24 09:00", zone: office, layers:)
        assert_equal ["eco", "calendar:leave:leave", at("2026-12-24 23:00")],
                     decision.to_h.values_at(:label, :source, :until)
    end

    private

    def holiday = @zone.timetable.specials.fetch("holiday")

    def office_with(specials)
        timetable = @zone.timetable.with(specials:)
        Schedule::Zone.new(name: "office", timetable:)
    end

    def calendar(*entries) = [base, Schedule::Layers::Calendar.new(entries)]
end
