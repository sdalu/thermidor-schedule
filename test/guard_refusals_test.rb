# frozen_string_literal: true

require "test_helper"
require "support"

# Guards refused: a zone's leaving no band between them, one bounding
# nothing or given no band; and the text forms a guard is read from.
class GuardRefusalsTest < Minitest::Test
    Schedule = Thermidor::Schedule
    Guard    = Schedule::Layers::Guard

    def teardown
        Schedule.configure(**Schedule::Config::DEFAULT.to_h)
    end

    # Crossed, touching, or less than the deadband apart, as the clamp's
    # limits; humidity bounds crossed or touching.
    def test_guards_holding_no_band_are_refused
        [%w[+20.. ..+18], %w[+25.. ..+25], %w[+24.6.. ..+25],
         %w[@70.. @..65], %w[@65.. @..65]].each do |texts|
            guards = texts.map { guard(it, it) }
            assert_raises(Schedule::Error, texts) { Guard.new(guards) }
        end
        Guard.new([guard("warm", "+24.."), guard("cap", "..+25")])
        Guard.new([guard("hot", "+20.."), guard("cold", "..+18",
                                                zone: "office")])
    end

    def test_the_deadband_is_the_configured_one
        guards = [guard("warm", "+24.."), guard("cap", "..+25")]
        Schedule.configure(deadband: 2.0)
        assert_raises(Schedule::Error) { Guard.new(guards) }
    end

    def test_a_guard_bounding_nothing_is_refused
        assert_raises(Schedule::Error) do
            Guard::Entry.new(zone: "salon", name: "none",
                             bounds: Schedule::Syntax.band("off@"))
        end
        %w[off @ +20 @..x].each do |text|
            assert_raises(Schedule::ParseError, text) do
                Schedule::Syntax.guard(text)
            end
        end
    end

    # Its text, not yet read, is no band.
    def test_a_guard_given_no_band_is_refused
        refused = assert_raises(Schedule::Error) do
            Guard::Entry.new(zone: "salon", name: "frost", bounds: "+7..")
        end
        assert_equal 'guard frost: "+7.." is no band', refused.message
    end

    def test_the_guard_text_forms
        { "+15..+25@40..65" => "+15.0..+25.0@40..65", "+7.." => "+7.0..",
          "@..65" => "off@..65" }.each do |text, band|
            assert_equal band, Schedule::Syntax.guard(text).to_s
        end
    end

    private

    def guard(name, text, zone: "salon")
        Guard::Entry.new(zone:, name:, bounds: Schedule::Syntax.guard(text))
    end
end
