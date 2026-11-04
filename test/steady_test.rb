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

    def test_readings_before_opening_do_not_count
        before = [[OPENED - 600, 22.0], [OPENED - 300, 21.0]]
        readings = before + readings(20.0, 20.0, 20.0, 20.0, 20.0, 20.0,
                                     20.0, 20.0, 20.0)
        refute Steady.new.steady?(readings, OPENED)
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

    def readings(*values)
        values.each_with_index.map { |value, i| [OPENED + (120 * i), value] }
    end
end
