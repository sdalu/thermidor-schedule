# frozen_string_literal: true

require "test_helper"
require "support"

# A bare clock time with ahead: the first moment after now the clock
# reads it, the second pass of a repeated hour counted; a skipped time
# is the moment the clocks jump, as the timetable reads it. Paris:
# 2026-10-25 back from 03:00 CEST to 02:00 CET; 2027-03-28 on from 02:00
# CET to 03:00 CEST. (Ruling of 2026-11-05.)
class SyntaxAheadDaylightTest < Minitest::Test
    include ScheduleSupport

    Syntax = Thermidor::Schedule::Syntax

    CEST = "+02:00"
    CET  = "+01:00"

    def test_the_first_pass_when_still_ahead
        assert_ahead [2026, 10, 25, 2, 45, CEST], [2026, 10, 25, 2, 30, CEST],
                     "02:45"
    end

    def test_the_second_pass_when_the_first_is_past
        assert_ahead [2026, 10, 25, 2, 15, CET], [2026, 10, 25, 2, 30, CEST],
                     "02:15"
        assert_ahead [2026, 10, 25, 2, 45, CET], [2026, 10, 25, 2, 30, CET],
                     "02:45"
    end

    # At now is not after now: the second pass, an hour on.
    def test_now_itself_takes_the_second_pass
        assert_ahead [2026, 10, 25, 2, 30, CET], [2026, 10, 25, 2, 30, CEST],
                     "02:30"
    end

    def test_both_passes_gone_is_tomorrow
        assert_ahead [2026, 10, 26, 2, 15, CET], [2026, 10, 25, 2, 30, CET],
                     "02:15"
    end

    def test_a_skipped_time_is_the_jump_until_it_is_past
        assert_ahead [2027, 3, 28, 3, 0, CEST], [2027, 3, 28, 1, 50, CET],
                     "02:30"
        assert_ahead [2027, 3, 29, 2, 30, CEST], [2027, 3, 28, 3, 10, CEST],
                     "02:30"
        assert_ahead [2027, 3, 29, 2, 30, CEST], [2027, 3, 28, 3, 0, CEST],
                     "02:30"
    end

    # Lord Howe goes back half an hour: its second pass too.
    def test_a_half_hour_second_pass
        in_zone("Australia/Lord_Howe") do
            now = Time.new(2026, 4, 5, 1, 50, 0, "+11:00")
            assert_equal Time.new(2026, 4, 5, 1, 45, 0, "+10:30"),
                         Syntax.time("01:45", now, ahead: true)
        end
    end

    private

    def assert_ahead(expected, now, text)
        in_zone("Europe/Paris") do
            assert_equal Time.new(*expected[0, 5], 0, expected[5]),
                         Syntax.time(text, Time.new(*now[0, 5], 0, now[5]),
                                     ahead: true)
        end
    end
end
