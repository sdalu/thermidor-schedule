# frozen_string_literal: true

require "test_helper"

class ConfigTest < Minitest::Test
    Schedule = Thermidor::Schedule

    def teardown
        Schedule.configure(**Schedule::Config::DEFAULT.to_h)
    end

    def test_defaults_are_the_constants
        config = Schedule.config
        assert_equal [Schedule::STRATEGIES, Schedule::DEFAULT_STRATEGY,
                      Schedule::DEADBAND],
                     [config.strategies, config.default_strategy,
                      config.deadband]
    end

    def test_the_deadband_holds_every_band_built_after
        Schedule.configure(deadband: 1.5)
        error = assert_raises(Schedule::Error) do
            Schedule::Setpoint.new(heat: 20, cool: 21)
        end
        assert_match(/at least 1.5 below/, error.message)
        assert_equal "+20.0..+21.5",
                     Schedule::Setpoint.new(heat: 20, cool: 21.5).to_s
    end

    def test_the_clamp_separates_by_the_deadband
        Schedule.configure(deadband: 2.0)
        below = Schedule::Decision.new(
            setpoint: Schedule::Setpoint.new(heat: 29, cool: 31),
            strategy: :comfort, source: "manual", label: nil, until: nil
        )
        clamped = Schedule::Layers::Clamp.new.apply(nil, nil, below)
        assert_equal "+28.0..+30.0", clamped.setpoint.to_s
    end

    def test_strategies_are_the_ones_configured
        Schedule.configure(strategies: %w[eco boost], default_strategy: :eco)
        assert_equal :boost, Schedule.strategy("boost")
        error = assert_raises(Schedule::ParseError) do
            Schedule.strategy(:quiet)
        end
        assert_match(/unknown strategy quiet \(eco, boost\)/, error.message)
        assert_equal :eco, Schedule.resolve_strategy(nil, nil)
    end

    # Built before any configure call, the built-in presets carry
    # :cheapest and :quick; outside the vocabulary they count as unset.
    def test_a_strategy_outside_the_vocabulary_counts_as_unset
        Schedule.configure(strategies: %i[eco boost], default_strategy: :eco)
        zone  = Schedule::Zone.new(name: "salon")
        now   = Time.new(2026, 11, 2, 10)
        stack = Schedule::Stack.new([Schedule::Layers::Timetable.new,
                                     Schedule::Layers::Away.new(
                                         [], auto_since: now - 60
                                     )])
        decision = stack.resolve(zone, now)
        assert_equal ["away", :eco], [decision.label, decision.strategy]
        assert_equal :boost, Schedule.resolve_strategy(:quick, :boost)
    end

    def test_a_setting_left_out_is_kept
        Schedule.configure(deadband: 0.5)
        Schedule.configure(default_strategy: :quiet)
        assert_equal [0.5, :quiet], [Schedule.config.deadband,
                                     Schedule.config.default_strategy]
    end

    def test_refuses_settings_that_cannot_hold
        [{ strategies: [] }, { default_strategy: :fast },
         { strategies: %i[eco eco], default_strategy: :eco },
         { deadband: -1 }, { deadband: Float::NAN }, { deadband: "wide" },
         { default_strategy: nil }, { strategies: [:comfort, 5] }]
            .each do |changes|
                assert_raises(Schedule::Error, changes.inspect) do
                    Schedule.configure(**changes)
                end
            end
    end

    def test_a_strategy_is_a_name
        assert_raises(Schedule::ParseError) { Schedule.strategy(5) }
    end

    def test_a_refused_setting_changes_nothing
        assert_raises(Schedule::Error) { Schedule.configure(deadband: -1) }
        assert_equal Schedule::Config::DEFAULT, Schedule.config
    end
end
