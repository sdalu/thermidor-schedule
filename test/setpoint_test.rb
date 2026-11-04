# frozen_string_literal: true

require "test_helper"

class SetpointTest < Minitest::Test
    Schedule = Thermidor::Schedule

    def test_rounds_to_tenths
        setpoint = Schedule::Setpoint.new(heat: 20.04, cool: "25")
        assert_equal [20.0, 25.0], [setpoint.heat, setpoint.cool]
    end

    def test_enforces_the_deadband
        assert Schedule::Setpoint.new(heat: 24, cool: 25)
        assert Schedule::Setpoint.new(heat: 24.3, cool: 25.3)
        error = assert_raises(Schedule::Error) do
            Schedule::Setpoint.new(heat: 24.1, cool: 25)
        end
        assert_match(/at least 1.0 below/, error.message)
    end

    def test_open_sides_and_off
        assert_predicate Schedule::Setpoint.new, :off?
        refute_predicate Schedule::Setpoint.new(heat: 7), :off?
    end

    def test_prints_in_the_inline_notation
        assert_equal "+20.5..+25.0",
                     Schedule::Setpoint.new(heat: 20.5, cool: 25).to_s
        assert_equal "+7.0..", Schedule::Setpoint.new(heat: 7).to_s
        assert_equal "..+26.0", Schedule::Setpoint.new(cool: 26).to_s
        assert_equal "-2.0..+5.0",
                     Schedule::Setpoint.new(heat: -2, cool: 5).to_s
        assert_equal "off", Schedule::Setpoint.new.to_s
    end

    def test_refuses_a_side_that_is_no_temperature
        [Float::INFINITY, -Float::INFINITY, Float::NAN, "abc", "", [],
         :warm].each do |value|
            error = assert_raises(Schedule::Error, value.inspect) do
                Schedule::Setpoint.new(heat: value)
            end
            assert_match(/is no temperature/, error.message)
        end
    end
end
