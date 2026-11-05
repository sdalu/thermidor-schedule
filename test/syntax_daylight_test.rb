# frozen_string_literal: true

require "test_helper"
require "support"

# A time typed for a night the clocks change, in Paris, read as the
# timetable reads its transitions: one the clocks skip is the moment
# they jump, one they repeat the first of the two.
class SyntaxDaylightTest < Minitest::Test
    include ScheduleSupport

    Syntax = Thermidor::Schedule::Syntax

    def test_a_skipped_time_is_the_moment_the_clocks_jump
        in_zone("Europe/Paris") do
            assert_equal Time.new(2027, 3, 28, 3, 0, 0, "+02:00"),
                         Syntax.time("2027-03-28 02:30")
        end
    end

    def test_a_repeated_time_is_the_first
        in_zone("Europe/Paris") do
            assert_equal Time.new(2026, 10, 25, 2, 30, 0, "+02:00"),
                         Syntax.time("2026-10-25 02:30")
        end
    end

    def test_an_ordinary_time_is_as_typed
        in_zone("Europe/Paris") do
            assert_equal Time.new(2026, 10, 25, 4, 30, 0, "+01:00"),
                         Syntax.time("2026-10-25 04:30")
        end
    end
end
