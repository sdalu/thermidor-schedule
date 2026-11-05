# frozen_string_literal: true

require "test_helper"
require "support"

# A whole day a time zone skipped (Samoa, 30 December 2011, from UTC-10
# to UTC+14): its readings are the moment the clocks jumped, as a skipped
# hour's are, not the next day's same reading.
class LocalTimeSkippedDayTest < Minitest::Test
    include ScheduleSupport

    def test_a_skipped_day_is_the_moment_the_clocks_jumped
        in_zone("Pacific/Apia") do
            jump = Time.new(2011, 12, 31, 0, 0, 0, "+14:00")
            assert_equal jump, Schedule::LocalTime.at(Date.new(2011, 12, 30),
                                                      8 * 60)
            assert_equal jump, Schedule::Syntax.time("2011-12-30 08:00")
        end
    end
end
