# frozen_string_literal: true

require "test_helper"
require "support"

# The layers above the timetable. 2026-11-02 is a Monday.
class LayersTest < Minitest::Test
    include ScheduleSupport

    Entry = Schedule::Layers::Away::Entry

    def setup
        @zone = workday_zone
    end

    def test_the_latest_entry_wins
        layers = away(Entry.new("salon", nil, at("2026-11-02 06:00"), nil),
                      Entry.new("salon", ECO, at("2026-11-02 06:30"),
                                at("2026-11-02 10:00")))
        decision = resolve("2026-11-02 07:00", layers:)
        assert_equal ["eco", "away", at("2026-11-02 10:00")],
                     decision.to_h.values_at(:label, :source, :until)
    end

    def test_away_uses_the_default_preset
        layers = away(Entry.new("salon", nil, at("2026-11-02 06:00"), nil))
        decision = resolve("2026-11-02 10:00", layers:)
        assert_equal ["away", "away", nil, :cheapest],
                     decision.to_h.values_at(:label, :source, :until,
                                             :strategy)
    end

    def test_away_ends_and_the_timetable_resumes
        layers = away(Entry.new("salon", nil, at("2026-11-02 06:00"),
                                at("2026-11-02 12:00")))
        sources = ["2026-11-02 05:00", "2026-11-02 11:59",
                   "2026-11-02 12:00"].map { resolve(it, layers:).source }
        assert_equal %w[timetable:workday away timetable:workday], sources
    end

    def test_away_for_another_zone_is_transparent
        layers = away(Entry.new("office", nil, at("2026-11-02 06:00"), nil))
        assert_equal "eco", resolve("2026-11-02 09:00", layers:).label
    end

    def test_clamp_keeps_both_sides_within_limits
        assert_equal [5.0, 30.0], clamp(2, 40)
        assert_equal [29.8, nil], clamp(29.8, nil)
        assert_equal [nil, 5.0], clamp(nil, 3)
    end

    def test_clamp_keeps_the_deadband_at_the_top
        assert_equal [29.0, 30.0], clamp(31, 33)
    end

    private

    def away(*entries) = [base, Schedule::Layers::Away.new(entries)]

    def clamp(heat, cool)
        below = Schedule::Decision.new(
            setpoint: Schedule::Setpoint.new(heat:, cool:),
            strategy: :comfort, source: "x", label: nil, until: nil
        )
        decision = Schedule::Layers::Clamp.new.apply(@zone, nil, below)
        [decision.setpoint.heat, decision.setpoint.cool]
    end
end
