# frozen_string_literal: true

require "test_helper"
require "support"

# Transitions holding a keyword instead of a preset, in the weekday
# timetable alone (where pass and usual have nothing below them but the
# fallback) and as values and text. 2026-11-02 is a Monday.
class ThroughTest < Minitest::Test
    include ScheduleSupport

    def test_a_weekday_program_lets_the_fallback_through
        %i[pass usual fallback].each do |word|
            @zone = zone_running("06:30" => COMFORT, "22:00" => word)
            decision = resolve("2026-11-02 23:00")
            assert_equal ["frost", "fallback", at("2026-11-03 06:30")],
                         decision.to_h.values_at(:label, :source, :until),
                         word
        end
    end

    def test_a_keyword_ends_a_stretch_like_any_transition
        @zone = zone_running("06:30" => COMFORT, "22:00" => :usual)
        assert_equal at("2026-11-02 22:00"), resolve("2026-11-02 12:00").until
    end

    def test_a_keyword_on_a_night_clocks_go_forward
        in_zone("Europe/Paris") do
            @zone = zone_running("01:00" => COMFORT, "02:30" => :pass)
            assert_equal Time.new(2026, 3, 29, 3, 0),
                         resolve("2026-03-29 01:30").until
            assert_equal %w[frost fallback],
                         resolve("2026-03-29 03:05").to_h
                                                    .values_at(:label, :source)
        end
    end

    def test_a_keyword_takes_no_preset_nor_strategy
        [{ through: :pass, preset: COMFORT },
         { through: :pass, strategy: :quick },
         { through: :again }, {}].each do |args|
            assert_raises(Schedule::Error, args.inspect) do
                Schedule::Transition.new(minute: 60, **args)
            end
        end
    end

    def test_keywords_are_read_and_reserved
        transition = Schedule::Syntax.transition("22:00=pass")
        assert_equal [nil, :pass], [transition.preset, transition.through]
        assert_raises(Schedule::ParseError) do
            Schedule::Syntax.transition("22:00=usual/quick")
        end
        assert_raises(Schedule::Error) do
            Schedule::Preset.new(name: "fallback", setpoint: COMFORT.setpoint)
        end
    end

    # An empty strategy is none, on a keyword as on a preset.
    def test_an_empty_strategy_on_a_keyword_is_none
        transition = Schedule::Transition.new(minute: 60, through: :pass,
                                              strategy: "")
        assert_nil transition.strategy
    end

    private

    def zone_running(steps)
        transitions = steps.map do |clock, value|
            minute = Schedule::Syntax.minute(clock)
            next Schedule::Transition.new(minute:, through: value) if
                value.is_a?(Symbol)
            Schedule::Transition.new(minute:, preset: value)
        end
        days = (0..6).to_h { [it, Schedule::Program.new(transitions:)] }
        Schedule::Zone.new(name: "salon",
                           timetable: Schedule::Timetable.new(days:))
    end
end
