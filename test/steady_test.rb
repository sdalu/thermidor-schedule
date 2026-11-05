# frozen_string_literal: true

require "test_helper"

# A window opened at OPENED; one reading every two minutes from then.
class SteadyTest < Minitest::Test
    Steady = Thermidor::Schedule::Steady
    OPENED = Time.new(2026, 11, 2, 9, 0)

    def test_shut_once_cooled_rebounded_and_settled
        assert steady?(21.0, 20.0, 19.0, 18.8, 19.6, 20.0, 20.0, 20.1, 20.0,
                       20.0, 20.0, 20.1)
    end

    def test_shut_once_warmed_rebounded_and_settled_while_cooling
        assert steady?(24.0, 25.0, 26.0, 26.2, 25.4, 25.0, 25.0, 24.9, 25.0,
                       25.0, 25.0, 24.9)
    end

    # Readings at the tenth meet each threshold exactly: 20.6 - 20.4 is
    # 0.20000000000000284 in floats, 16.9 - 14.9 is 1.9999999999999982.
    def test_a_spread_of_exactly_the_tolerance_is_settled
        assert steady?(21.0, 20.0, 19.0, 18.8, 19.6, 20.4, 20.4, 20.5, 20.6,
                       20.5, 20.6, 20.6)
    end

    def test_a_move_of_exactly_the_change_counts
        assert steady?(16.9, 15.9, 14.9, 15.9, 15.9, 15.9, 15.9, 15.9, 15.9,
                       15.9)
    end

    def test_a_rebound_of_exactly_the_fraction_counts
        assert steady?(16.1, 15.1, 14.1, 15.1, 15.1, 15.1, 15.1, 15.1, 15.1,
                       15.1)
    end

    # A sensor read every 15 minutes: the last 10 minutes hold a single
    # reading, but the room went from 20.0 to 21.5 across them. What was
    # in force when they began counts, as the last reading before.
    def test_a_slow_sensor_still_moving_is_not_settled
        readings = [[0, 21.0], [15, 19.0], [30, 20.0], [45, 21.5]]
                   .map { |minute, value| [OPENED + (minute * 60), value] }
        refute Steady.new.steady?(readings, OPENED)
    end

    def test_a_small_turn_back_is_not_a_rebound
        refute steady?(21.0, 20.0, 19.0, 18.8, 19.4, 19.5, 19.5, 19.6, 19.5,
                       19.5, 19.5, 19.6)
    end

    def test_cooled_and_flat_without_a_rebound_is_still_open
        refute steady?(21.0, 20.0, 19.0, 19.0, 19.0, 19.0, 19.0, 19.0, 19.0,
                       19.0, 19.0, 19.0)
    end

    def test_the_settling_counts_from_the_rebound
        refute steady?(21.0, 19.0, 19.0, 19.0, 19.0, 19.0, 19.0, 20.0, 20.0)
    end

    def test_still_cooling
        refute steady?(21.0, 20.4, 19.8, 19.4, 19.0, 18.7, 18.5, 18.3, 18.1)
    end

    def test_a_mild_day_that_never_moves
        refute steady?(20.0, 19.6, 19.4, 19.6, 19.6, 19.6, 19.6, 19.6, 19.6,
                       19.6)
    end

    def test_not_before_fifteen_minutes
        early = [21.0, 19.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0]
        refute steady?(*early)
        assert steady?(*early, 20.0)
    end

    # Readings before opening are no part of the move: from the last of
    # them, 21.0, a flat 20.0 is a 1 °C move, not enough. (Nor would it
    # be from 22.0: there is no rebound either.)
    def test_a_fall_before_opening_is_no_move
        before = [[OPENED - 600, 22.0], [OPENED - 300, 21.0]]
        readings = before + readings(20.0, 20.0, 20.0, 20.0, 20.0, 20.0,
                                     20.0, 20.0, 20.0)
        refute Steady.new.steady?(readings, OPENED)
    end

    # A sensor read just before the window opened, then two minutes
    # after: the move counts from 21.0, not from the first 19.0.
    def test_the_baseline_is_the_last_reading_before_opening
        assert steady_after?([[-60, 21.0]],
                             19.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0)
    end

    # Only the last reading before opening counts: from 23.0 the dip to
    # 19.0 would be 4 °C, and 20.0 too small a rebound.
    def test_only_the_last_reading_before_opening_is_the_baseline
        assert steady_after?([[-600, 23.0], [-60, 21.0]],
                             19.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0)
    end

    # With none before, the first since opening.
    def test_without_one_before_the_first_since_opening
        refute steady_after?([], 19.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0,
                             20.0)
    end

    def test_the_move_and_rebound_are_tunable
        small = [20.0, 19.0, 19.5, 19.5, 19.5, 19.5, 19.5, 19.5, 19.5]
        refute steady?(*small)
        assert Steady.new(change: 1.0).steady?(readings(*small), OPENED)
        refute Steady.new(change: 1.0, rebound: 0.75)
                     .steady?(readings(*small), OPENED)
    end

    def test_nothing_to_go_by
        refute Steady.new.steady?([], OPENED)
    end

    private

    def steady?(*values) = Steady.new.steady?(readings(*values), OPENED)

    # `before`: [[seconds from opening, °C], ...]; `values` read every two
    # minutes from two minutes after opening.
    def steady_after?(before, *values)
        earlier = before.map { |offset, value| [OPENED + offset, value] }
        later = values.each_with_index.map do |value, i|
            [OPENED + (120 * (i + 1)), value]
        end
        Steady.new.steady?(earlier + later, OPENED)
    end

    def readings(*values)
        values.each_with_index.map { |value, i| [OPENED + (120 * i), value] }
    end
end
