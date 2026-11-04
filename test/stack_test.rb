# frozen_string_literal: true

require "test_helper"
require "support"

# 2026-11-02 is a Monday.
class StackTest < Minitest::Test
    include ScheduleSupport

    # Active between `from` and `to`: holds `preset` until `to`.
    FakeLayer = Data.define(:preset, :from, :to) do
        def apply(zone, now, below)
            return below unless (from...to).cover?(now)
            Schedule::Decision.from_preset(preset, zone, source: "fake",
                                                         until: to)
        end
    end

    PLAIN = Schedule::Preset.new(name: "plain",
                                 setpoint: Schedule::Setpoint.new(heat: 20))

    def setup
        @zone = workday_zone
    end

    def test_timetable_decides
        decision = resolve("2026-11-02 07:00")
        assert_equal ["comfort", :quick, "timetable:workday",
                      at("2026-11-02 08:30")],
                     decision.to_h.values_at(:label, :strategy, :source, :until)
    end

    def test_transition_then_preset_strategy_beat_the_zone
        zone = workday_zone(strategy: :quiet)
        assert_equal :quick, resolve("2026-11-02 07:00", zone:).strategy
        assert_equal :cheapest, resolve("2026-11-02 09:00", zone:).strategy
    end

    def test_zone_strategy_then_the_default
        attic  = Schedule::Zone.new(name: "attic", strategy: :quiet)
        layers = [base(PLAIN)]
        assert_equal :quiet,
                     resolve("2026-11-02 07:00", zone: attic, layers:).strategy
        plain = attic.with(strategy: nil)
        assert_equal :comfort,
                     resolve("2026-11-02 07:00", zone: plain, layers:).strategy
    end

    def test_zone_without_timetable_gets_the_fallback
        decision = resolve("2026-11-02 07:00",
                           zone: Schedule::Zone.new(name: "attic"))
        assert_equal ["frost", "fallback", nil],
                     decision.to_h.values_at(:label, :source, :until)
    end

    def test_top_layer_wins_then_hands_back
        layer = FakeLayer.new(NIGHT, at("2026-11-02 10:00"),
                              at("2026-11-02 11:00"))
        layers = [base, layer]
        assert_equal "fake", resolve("2026-11-02 10:30", layers:).source
        assert_equal "eco", resolve("2026-11-02 11:00", layers:).label
    end

    def test_wake_at_is_the_earliest_change_in_the_stack
        layer = FakeLayer.new(NIGHT, at("2026-11-02 08:00"),
                              at("2026-11-02 12:00"))
        stack = Schedule::Stack.new([base, layer])
        assert_equal at("2026-11-02 08:30"),
                     stack.wake_at(@zone, at("2026-11-02 08:10"))
    end
end
