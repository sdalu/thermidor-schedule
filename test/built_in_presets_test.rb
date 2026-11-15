# frozen_string_literal: true

require "test_helper"

# The built-in presets are built for the settings in force: a deadband
# configured wider than their sides keeps them whole.
class BuiltInPresetsTest < Minitest::Test
    Schedule = Thermidor::Schedule

    def teardown
        Schedule.configure(**Schedule::Config::DEFAULT.to_h)
    end

    def test_a_built_in_band_widens_as_the_clamp_would
        Schedule.configure(deadband: 2.0)
        boost = Schedule::Preset.boost.setpoint
        assert_equal [23.0, 25.0], [boost.heat, boost.cool]
        assert_equal %w[frost away boost boost-heat boost-cool open-window],
                     Schedule::Preset.system.map(&:name)
    end

    def test_a_built_in_strategy_not_configured_is_left_out
        Schedule.configure(strategies: %i[comfort], default_strategy: :comfort)
        assert_nil Schedule::Preset.boost.strategy
    end

    # The built-in presets follow the deadband configured: a boost, two
    # sides one degree apart by default, keeps its heat and cools from
    # heat plus the gap, over a band with humidity bounds or under a
    # ceiling guard alike.
    def test_the_built_in_presets_follow_a_wider_deadband
        Schedule.configure(deadband: 2.0)
        now = Time.new(2026, 11, 2, 12)
        setpoint = Schedule::Stack.new(layers(now)).resolve(zone, now).setpoint
        assert_equal [23.0, 25.0], [setpoint.heat, setpoint.cool]
    end

    private

    def layers(now)
        [Schedule::Layers::Timetable.new,
         Schedule::Layers::Manual.new([held(now, humid_band)]),
         Schedule::Layers::Boost.new([boost(now)]),
         Schedule::Layers::Guard.new([ceiling]),
         Schedule::Layers::Clamp.new]
    end

    def zone = Schedule::Zone.new(name: "salon")

    def humid_band
        Schedule::Preset.new(name: "wet", setpoint: Schedule::Setpoint.new(
            heat: 19, cool: 26, humidity: Schedule::Humidity.new(high: 60)
        ))
    end

    def held(now, preset)
        Schedule::Layers::Manual::Entry.new(
            zone: "salon", preset:, strategy: nil, starts_at: now - 120,
            ends_at: nil, mode: :forever
        )
    end

    def boost(now)
        Schedule::Layers::Manual::Entry.new(
            zone: "salon", preset: nil, strategy: nil, starts_at: now - 60,
            ends_at: now + 600, mode: :both
        )
    end

    def ceiling
        Schedule::Layers::Guard::Entry.new(
            zone: "salon", name: "ceiling", bounds: Schedule::Syntax.guard("..+28")
        )
    end
end
