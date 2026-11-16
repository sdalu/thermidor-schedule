# frozen_string_literal: true

require "test_helper"

# The house's settings beyond the vocabulary: the clamp's limits, the
# durations of settings by hand, the auto-away delay and Steady's
# thresholds. A layer or rule built without an argument takes the
# setting in force when built; an argument still says otherwise for its
# own.
class HouseSettingsTest < Minitest::Test
    Schedule = Thermidor::Schedule
    Layers   = Schedule::Layers

    def teardown
        Schedule.configure(**Schedule::Config::DEFAULT.to_h)
    end

    def test_the_clamp_takes_the_limits_configured
        Schedule.configure(clamp_limits: 10.0..25.0)
        assert_equal "+10.0..+25.0", clamped(8, 28)
        assert_equal "+8.0..+28.0", clamped(8, 28, limits: 5.0..30.0)
    end

    def test_auto_away_takes_the_delay_configured
        Schedule.configure(auto_away_leave: 300)
        assert_equal 300, Schedule::AutoAway.new.leave
        assert_equal 60, Schedule::AutoAway.new(leave: 60).leave
    end

    def test_steady_takes_the_thresholds_configured
        Schedule.configure(steady_span: 120, steady_rebound: 0.25)
        steady = Schedule::Steady.new(change: 1.0)
        assert_equal [120, 0.25, 1.0, 0.2],
                     [steady.span, steady.rebound, steady.change,
                      steady.tolerance]
    end

    def test_the_durations_by_hand_are_the_settings
        Schedule.configure(manual_longest: 4 * 3600, boost_duration: 600,
                           boost_longest: 1800, open_window_limit: 900,
                           open_window_longest: 5400)
        assert_equal [4 * 3600, 600, 1800, 900, 5400],
                     [Layers::Manual.longest, Layers::Boost.duration,
                      Layers::Boost.longest, Layers::OpenWindow.limit,
                      Layers::OpenWindow.longest]
    end

    # The refusal names the longest configured, in hours when whole.
    def test_a_duration_over_the_longest_says_it
        Schedule.configure(manual_longest: 4 * 3600, boost_longest: 1800,
                           boost_duration: 600, open_window_longest: 5400)
        { Layers::Manual => "a manual setting lasts 0 to 4 hours",
          Layers::Boost => "a boost lasts 0 to 30 minutes",
          Layers::OpenWindow => "an open window lasts 0 to 90 minutes" }
            .each { |layer, message| assert_equal message, refusal(layer) }
    end

    def test_refuses_limits_holding_no_band
        [{ clamp_limits: 20.0..20.5 }, { clamp_limits: 5.0...30.0 },
         { clamp_limits: (5.0..) }, { clamp_limits: 30 },
         { deadband: 30 }].each { refused(it) }
    end

    def test_refuses_durations_that_cannot_hold
        [{ manual_longest: 0 }, { boost_longest: 1.5 },
         { boost_duration: 2 * 3600 }, { open_window_limit: 3 * 3600 },
         { auto_away_leave: -1 }, { auto_away_leave: nil }]
            .each { refused(it) }
    end

    def test_refuses_thresholds_out_of_range
        [{ steady_rebound: 1.5 }, { steady_span: -1 },
         { steady_tolerance: Float::INFINITY }, { steady_after: "15m" }]
            .each { refused(it) }
    end

    private

    def refusal(layer)
        assert_raises(Schedule::Error) do
            layer.check_duration((4 * 3600) + 1)
        end.message
    end

    def refused(changes)
        assert_raises(Schedule::Error, changes.inspect) do
            Schedule.configure(**changes)
        end
        assert_equal Schedule::Config::DEFAULT, Schedule.config
    end

    def clamped(heat, cool, **)
        below = Schedule::Decision.new(
            setpoint: Schedule::Setpoint.new(heat:, cool:),
            strategy: :comfort, source: "manual", label: nil, until: nil
        )
        Layers::Clamp.new(**).apply(nil, nil, below).setpoint.to_s
    end
end
