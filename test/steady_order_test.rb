# frozen_string_literal: true

require "test_helper"

# Readings come in any order (Steady#steady?): two at the same moment
# (two sensors) count as one, their mean, so the answer does not depend
# on which is listed first.
class SteadyOrderTest < Minitest::Test
    Steady = Thermidor::Schedule::Steady

    OPENED = Time.new(2026, 11, 5, 12, 0, 0, "+01:00")

    def test_readings_at_one_moment_count_as_their_mean
        later = [[0, 18.9], [20, 18.9], [40, 19.6], [60, 19.7], [75, 19.7],
                 [90, 19.7]].map { |minutes, value| [at(minutes), value] }
        both = [[OPENED, 21.0], [OPENED, 19.0]]
        steady = Steady.new
        assert_equal steady.steady?(both + later, OPENED),
                     steady.steady?(both.reverse + later, OPENED)
        assert_equal steady.steady?([[OPENED, 20.0]] + later, OPENED),
                     steady.steady?(both + later, OPENED)
    end

    private

    def at(minutes) = OPENED + (minutes * 60)
end
