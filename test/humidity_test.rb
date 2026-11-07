# frozen_string_literal: true

require "test_helper"

# Humidity bounds on a band, and their text form after "@": a floor, a
# ceiling or both, in % of relative humidity; a bare "@" clears.
class HumidityTest < Minitest::Test
    Schedule = Thermidor::Schedule
    Humidity = Schedule::Humidity
    Syntax   = Schedule::Syntax

    # What is read, and what prints back: the canonical form.
    CANONICAL = { "+20..+26@30..60" => "+20.0..+26.0@30..60",
                  "+20..+26@..60" => "+20.0..+26.0@..60",
                  "+20..+26@30.." => "+20.0..+26.0@30..",
                  "+20..+26@60" => "+20.0..+26.0@..60",
                  "+22..@" => "+22.0..@",
                  "..+26@..55.5" => "..+26.0@..55.5",
                  "+20..+26" => "+20.0..+26.0" }.freeze

    def test_rounds_to_tenths_and_prints_without_a_sign
        humidity = Humidity.new(low: "30", high: 59.96)
        assert_equal [30.0, 60.0], [humidity.low, humidity.high]
        assert_equal "30..60", humidity.to_s
        assert_equal "..55.5", Humidity.new(high: 55.5).to_s
        assert_equal "30..", Humidity.new(low: 30).to_s
    end

    def test_none_clears
        assert_equal "", Humidity::NONE.to_s
        assert_predicate Humidity::NONE, :none?
        refute_predicate Humidity.new(high: 60), :none?
    end

    def test_refuses_what_is_no_relative_humidity
        [-1, 100.1, Float::NAN, "abc", :damp].each do |value|
            assert_raises(Schedule::Error, value.inspect) do
                Humidity.new(high: value)
            end
        end
        [[60, 30], [50, 50]].each do |low, high|
            error = assert_raises(Schedule::Error) { Humidity.new(low:, high:) }
            assert_match(/below/, error.message)
        end
    end

    def test_a_band_carries_it_after_its_sides
        setpoint = Schedule::Setpoint.new(heat: 20, cool: 26,
                                          humidity: Humidity.new(high: 60))
        assert_equal "+20.0..+26.0@..60", setpoint.to_s
        assert_nil Schedule::Setpoint.new(heat: 20).humidity
        assert_equal "+20.0..@",
                     Schedule::Setpoint.new(heat: 20,
                                            humidity: Humidity::NONE).to_s
        assert_raises(Schedule::Error) do
            Schedule::Setpoint.new(heat: 20, humidity: 60)
        end
    end

    # off has no temperature side, and may still carry a humidity bound.
    def test_off_with_a_ceiling
        setpoint = Syntax.preset("off@..65").setpoint
        assert_predicate setpoint, :off?
        assert_equal [nil, 65.0], setpoint.humidity.to_h.values_at(:low, :high)
        assert_equal "off@..65", setpoint.to_s
        assert_equal "off@", Syntax.preset("off@").setpoint.to_s
        assert_equal "office", Syntax.preset("office")
    end

    # The short form "@60" is a ceiling; what prints is the canonical form.
    def test_reads_and_prints_back_the_canonical_form
        CANONICAL.each do |text, printed|
            setpoint = Syntax.preset(text).setpoint
            assert_equal printed, setpoint.to_s, text
            assert_equal setpoint, Syntax.preset(printed).setpoint, printed
        end
    end

    def test_the_strategy_comes_last
        preset, strategy = Syntax.preset_ref("+20..+26@..60/quiet")
        assert_equal ["+20.0..+26.0@..60", :quiet], [preset.label, strategy]
        transition = Syntax.transition("06:30=+20..+26@..60/quiet")
        assert_equal 60.0, transition.preset.setpoint.humidity.high
    end

    def test_refuses_a_bad_humidity_part
        %w[+20..+26@.. +20..+26@-5 +20..+26@+60 +20..+26@101 +20..+26@60..30
           +20..+26@abc +20..+26@60@70 @..60 off@60..30].each do |text|
            assert_raises(Schedule::ParseError, text) { Syntax.preset(text) }
        end
    end
end
